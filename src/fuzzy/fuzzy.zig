//! Zig implementation of fzf V1 and V2 fuzzy matching algorithms.
//! https://github.com/junegunn/fzf

pub const Rune = i32;

/// Match result
pub const Result = struct {
    start: i32, // -1 no match
    end: i32, // -1 no match
    score: i32, // 0 for no match, can be negative in some cases

    /// Start = end = -1; score = 0
    pub fn noMatch() Result {
        return .{ .start = -1, .end = -1, .score = 0 };
    }

    pub fn isMatch(self: Result) bool {
        return self.start >= 0;
    }
};

//Character classification system
const CharClass = enum(u8) {
    white, //Spaces, tabs, newlines
    non_word, //Punctuation: !, @, #, ...
    delimiter, // '/' ',' ':' ';'
    lower, // a-z
    upper, // A-Z
    letter, //Non ascii letters
    number, //0-9
};
pub const MAX_CHAR_CLASS = @intFromEnum(CharClass.number);
pub const MAX_ASCII: usize = 127;

//TODO: handle different separaters based on OS
const delimiter_chars = [_]u8{'/'};
const white_chars = [_]u8{
    ' ', // space
    '\t', // tab
    '\n', // newline
    '\x0b', // vertical tab
    '\x0c', // form feed
    '\r', // carriage return
    '\x85', // next line (NEL)
    '\xA0', // non-breaking space
};

// Example: Matching "ac" in "abc":
// 'a' matches: +16 points
// 'b' is skipped: -3 (gap start)
// 'c' matches: +16 points
const SCORE_MATCH: i32 = 16; //Base points for any char match
const SCORE_GAP_START: i32 = -3; //Penalty for starting a gap (char not eq to next char in match)
const SCORE_GAP_EXTENSION: i32 = -1; //Penalty for each additional gap character

// Bonus system
// We prefer matches at the beginning of a word. The bonus point is chosen so that the bonus
// is cancelled when the gap between the acronyms grows over 8 chars, which is approx the
// average length of the words found in web2 dictionary and fzf writer file system.
const BONUS_BOUNDARY: i32 = SCORE_MATCH / 2;
const BONUS_NON_WORD: i32 = SCORE_MATCH / 2;
const BONUS_CAMEL_123: i32 = BONUS_BOUNDARY + SCORE_GAP_EXTENSION;
const BONUS_CONSECUTIVE: i32 = -(SCORE_GAP_START + SCORE_GAP_EXTENSION);
const BONUS_FIRST_CHAR_MULTIPLIER: i32 = 2;

var bonus_boundary_white: i16 = BONUS_BOUNDARY + 2; //Might change based on schema
var bonus_boundary_delimiter: i16 = BONUS_BOUNDARY + 1; //Might change based on schema
var initial_char_class: CharClass = CharClass.white;

/// Ascii optimization table (maps each ascii to its CharClass) (15%+ performance boost)
var ascii_char_classes: [MAX_ASCII + 1]CharClass = undefined;
/// Lookup table with precalculated bonuses (+5% performance boost)
var bonus_matrix: [MAX_CHAR_CLASS + 1][MAX_CHAR_CLASS + 1]i16 = undefined;

/// Calculates bonus based on character transitions
fn bonusFor(prev_class: CharClass, class: CharClass) i16 {
    //Check if current char can start a word
    if (@intFromEnum(class) > @intFromEnum(CharClass.non_word)) {
        switch (prev_class) {
            .white => return bonus_boundary_white, // space -> letter
            .delimiter => return bonus_boundary_delimiter, // delimter -> letter
            .non_word => return BONUS_BOUNDARY, //punct -> letter
            else => {},
        }
    }

    // Bonus for camelCase and letter->number 'test123'
    if ((prev_class == .lower and class == .upper) or
        (prev_class != .number and class == .number))
    {
        return @intCast(BONUS_CAMEL_123);
    }

    //Non word characters get bonuses too (for matching after them)
    switch (class) {
        .non_word, .delimiter => return BONUS_NON_WORD,
        .white => return bonus_boundary_white,
        else => return 0,
    }
}

const Scheme = enum {
    default,
    path,
    history,
};

//TODO: could make Scheme enum pub and directly get enum
pub fn fuzzyInit(scheme: []const u8) void {
    const chosen_scheme = std.meta.stringToEnum(Scheme, scheme) orelse Scheme.default;
    switch (chosen_scheme) {
        .default => {
            bonus_boundary_white = BONUS_BOUNDARY + 2;
            bonus_boundary_delimiter = BONUS_BOUNDARY + 1;
        },
        .path => {
            bonus_boundary_white = BONUS_BOUNDARY;
            bonus_boundary_delimiter = BONUS_BOUNDARY + 1;
            //TODO choose different delimiter based on os
            initial_char_class = .delimiter;
        },
        .history => {
            bonus_boundary_white = BONUS_BOUNDARY;
            bonus_boundary_delimiter = BONUS_BOUNDARY;
        },
    }

    //Fill ascii char classes lookup table
    for (0..MAX_ASCII) |i| {
        const char: u8 = @intCast(i);
        var class: CharClass = undefined;
        if (std.ascii.isLower(char)) {
            class = .lower;
        } else if (std.ascii.isUpper(char)) {
            class = .upper;
        } else if (std.ascii.isDigit(char)) {
            class = .number;
        } else if (std.mem.containsAtLeast(u8, &delimiter_chars, 1, &.{char})) {
            class = .delimiter;
        } else if (std.mem.containsAtLeast(u8, &white_chars, 1, &.{char})) {
            class = .white;
        } else {
            class = .non_word;
        }
        ascii_char_classes[i] = class;
    }

    // Fill bonus matrix
    // Precompute bonus for all possible combinations of char classes
    for (0..MAX_CHAR_CLASS + 1) |i| {
        for (0..MAX_CHAR_CLASS + 1) |j| {
            bonus_matrix[i][j] = bonusFor(@enumFromInt(i), @enumFromInt(j));
        }
    }
    return;
}

/// Returns index of next occurence of pattern_byte in input starting from 'from'.
/// If case_sensitive is false, it finds the first lowercase occurence
/// and checks if there is an uppercase one.
/// Returns uppercase position first otherwise lowercase position.
/// If case_sensitive is true uppercase and lowercase are treated as different chars.
fn trySkip(input: Chars, case_sensitive: bool, pattern_byte: u8, from: usize) i32 {
    var byte_array = input.slice[from..];
    if (std.mem.indexOf(u8, byte_array, &[_]u8{pattern_byte})) |index_found| {
        if (index_found == 0) {
            //Cant skip any further
            return @intCast(from);
        }
        var idx = index_found;
        // We may need to search for the uppercase letter again. We dont have to
        // consider normalization as we can be sure that this is an ascii string.
        if (!case_sensitive and std.ascii.isLower(pattern_byte)) {
            if (idx > 0) {
                byte_array = byte_array[0..idx];
            }
            //Look for uppercase version before the lowercase position
            const uidx = std.mem.indexOf(u8, byte_array, &[_]u8{pattern_byte - 32});
            if (uidx != null and uidx.? >= 0) {
                idx = uidx.?;
            }
        }
        return @intCast(from + idx);
    }
    return -1;
}

/// Computes min and max index which delimit the slice of input that might contain the match.
/// It's an optimization in case of ascii only. The goal is to narrow down the scope 
/// onto which to apply the actual matching algorithm.
/// Returns start index and end index + 1 of the new scope.
fn asciiFuzzyIndex(input: Chars, pattern: []const Rune, case_sensitive: bool) struct { i32, i32 } {
    // Not possible because input is not ascii only
    if (!input.is_ascii) {
        const end: i32 = @intCast(input.slice.len); //THIS LENGTH IS WRONG
        return .{ 0, end };
    }

    //Not possible because pattern is not ascii only.
    for (pattern) |b| {
        const byte: u8 = @intCast(b);
        if (!std.ascii.isAscii(byte)) {
            return .{ -1, -1 };
        }
    }

    //Both pattern and input are ascii only
    var first_idx: i32 = 0;
    var idx: i32 = 0;
    var last_idx: i32 = 0;
    var byte: u8 = undefined;
    for (0..pattern.len) |pidx| {
        //We know pidx to be ascii so u8 is fine
        byte = @intCast(pattern[pidx]);
        idx = trySkip(input, case_sensitive, byte, @as(usize, @intCast(idx)));
        if (idx < 0) {
            return .{ -1, -1 };
        }
        // if we found the first pattern byte in the input
        // we step back to find the right bonus point
        if (pidx == 0 and idx > 0) {
            first_idx = idx - 1;
        }
        last_idx = idx;
        idx += 1;
    }

    //Find last appereance of the last char in pattern to limit scope of match
    var bu = byte;
    if (!case_sensitive and std.ascii.isLower(byte)) {
        bu = byte - 32;
    }
    const last_idx_usize: usize = @intCast(last_idx);
    const scope = input.slice[last_idx_usize..];
    var offset: usize = scope.len - 1;
    while (offset > 0) : (offset -= 1) {
        if (scope[offset] == byte or scope[offset] == bu) {
            const offset_i32: i32 = @intCast(offset);
            return .{ first_idx, last_idx + offset_i32 + 1 };
        }
    }
    return .{ first_idx, last_idx + 1 };
}

// fn fuzzyMatchV1(case_sensitive: bool, normalize: bool, forward: bool, 
// text: Chars, pattern: []Rune, with_pos: bool, slab: Slab) struct {Result, ?[]i32}{
//     if (pattern.len == 0) {
//         return .{Result{.start = 0, .end = 0, .score = 0}, null};
//     }
//
//     // Narrow search scope
//     const start_idx, _ = asciiFuzzyIndex(text, pattern, case_sensitive);
//     if (start_idx < 0) {
//         return .{Result.noMatch(), null};
//     }
//
//     const pidx: i32 = 0;
//     const sidx: i32 = -1;
//     const eidx: i32 = -1;
//
//     const len_runes = text.slice.len; //THIS LEN IS WRONG
//     const len_pattern = pattern.len;
//
// }

// //TODO remove prints and add expects
// test "init-fuzzy" {
//     fuzzyInit("default");
//     std.debug.print("Bonus matrix:\n", .{});
//     for (0..MAX_CHAR_CLASS + 1) |i| {
//         for (0..MAX_CHAR_CLASS + 1) |j| {
//             std.debug.print("{d} ", .{bonus_matrix[i][j]});
//         }
//         std.debug.print("\n", .{});
//     }
//     std.debug.print("Ascii lookup table:\n", .{});
//     for (ascii_char_classes) |class| {
//         std.debug.print("{s} ", .{@tagName(class)});
//     }
//     std.debug.print("\n", .{});
// }
//
// test "trySkip-case-sensitive" {
//     fuzzyInit("default");
//     const input = chars.toChars("foobar");
//     // Should find 'b' at position 3
//     try std.testing.expectEqual(3, trySkip(input, true, 'b', 0));
//
//     // Starting from position 4, should find nothing
//     try std.testing.expectEqual(-1, trySkip(input, true, 'b', 4));
//
//     // Should not find 'B' (case sensitive)
//     const input2 = chars.toChars("fooBar");
//     try std.testing.expectEqual(-1, trySkip(input2, true, 'b', 0));
// }
//
// test "trySkip-case-insensitive" {
//     fuzzyInit("default");
//
//     // Should find lowercase 'b'
//     const input1 = chars.toChars("fooobar");
//     try std.testing.expectEqual(4, trySkip(input1, false, 'b', 0));
//
//     // Should find first uppercase'B'
//     const input2 = chars.toChars("fooBabarbarBr");
//     try std.testing.expectEqual(3, trySkip(input2, false, 'b', 0));
//
//     // Should find first occurrence (uppercase comes first)
//     const input3 = chars.toChars("aBbcd");
//     try std.testing.expectEqual(1, trySkip(input3, false, 'b', 0));
//
//     // Starting from position 2, should find lowercase 'b'
//     try std.testing.expectEqual(2, trySkip(input3, false, 'b', 2));
// }
//
// test "asciiFuzzyIndex-basic-matching" {
//     fuzzyInit("default");
//
//     // Simple match: "fb" in "foobar"
//     const input1 = chars.toChars("foobar");
//     const pattern1 = [_]Rune{ 'f', 'o' };
//     const result1 = asciiFuzzyIndex(input1, &pattern1, true);
//     try std.testing.expectEqual(0, result1[0]);
//     try std.testing.expectEqual(3, result1[1]);
//
//     // Match with step back: "oo" in "foobar"
//     const input2 = chars.toChars("Hey-how-are-you-zazzorro-?-I-heard-ok!");
//     const pattern2 = [_]Rune{ 'z', 'o', 'r', 'r', 'o', '?' };
//     const startr, const endr = asciiFuzzyIndex(input2, &pattern2, false);
//     try expectEqual(startr, 15);
//     try expectEqual(endr, 26);
//     const start = @as(usize, @intCast(startr));
//     const end = @as(usize, @intCast(endr));
//     try std.testing.expectEqualDeep(input2.slice[start..end], "-zazzorro-?");
// }
//
// test "asciiFuzzyIndex extreme cases" {
//     fuzzyInit("default");
//
//     // Test 1: Pattern characters scattered with many occurrences
//     const input1 = chars.toChars("aaaaaaa_bbbbbbb_ccccccc_aaaaaaa_bbbbbbb_ccccccc");
//     const pattern1 = [_]Rune{ 'a', 'b', 'c' };
//     const r1 = asciiFuzzyIndex(input1, &pattern1, true);
//     // Should find: first 'a' at 0 (no stepback), first 'b' at 8, first 'c' at 16
//     // But extend to LAST 'c' at position 46
//     try std.testing.expectEqual(0, r1[0]);
//     try std.testing.expectEqual(47, r1[1]);  // 46 + 1
//
//     // // Test 2: Case insensitive with mixed case chaos
//     // const input2 = chars.toChars("AaAaAa_BbBbBb_CcCcCc_aAaAaA_bBbBbB_cCcCcC");
//     // const pattern2 = [_]Rune{ 'a', 'b', 'c' };
//     // const r2 = asciiFuzzyIndex(input2, &pattern2, false);
//     // // Should prefer uppercase: 'A' at 0, 'B' at 7, 'C' at 14
//     // // Extend to last 'C' (or 'c') at position 41
//     // try std.testing.expectEqual(0, r2[0]);
//     // try std.testing.expectEqual(42, r2[1]); //FAILS HERE, we get 41
//
//     // Test 3: Pattern at the very end with lookahead complications
//     const input3 = chars.toChars("xyz_xyz_xyz_abc");
//     const pattern3 = [_]Rune{ 'a', 'b', 'c' };
//     const r3 = asciiFuzzyIndex(input3, &pattern3, true);
//     // 'a' at 12, stepback to 11, extend to 15
//     try std.testing.expectEqual(11, r3[0]);
//     try std.testing.expectEqual(15, r3[1]);
//
//     // Test 4: Single character repeated everywhere
//     const input4 = chars.toChars("a_a_a_a_a_a_a_a_a_a_a_a_a_a_a");
//     const pattern4 = [_]Rune{ 'a' };
//     const r4 = asciiFuzzyIndex(input4, &pattern4, true);
//     // First 'a' at 0, extend to last 'a' at 28
//     try std.testing.expectEqual(0, r4[0]);
//     try std.testing.expectEqual(29, r4[1]);
//
//     // Test 5: The pathological case - pattern appears multiple times
//     const input5 = chars.toChars("abc_def_abC_ghi_abc_jkl_abc");
//     const pattern5 = [_]Rune{ 'a', 'b', 'C' };
//     const r5 = asciiFuzzyIndex(input5, &pattern5, true);
//     // First 'a' at 0, but must extend to LAST 'c' at 26
//     try std.testing.expectEqual(0, r5[0]);
//     try std.testing.expectEqual(11, r5[1]);
//
//     // // Test 6: Case insensitive with only uppercase in input
//     // const input6 = chars.toChars("FOOBAR");
//     // const pattern6 = [_]Rune{ 'f', 'b' };  // lowercase pattern
//     // const r6 = asciiFuzzyIndex(input6, &pattern6, false);
//     // // Should find 'F' at 0, 'B' at 3
//     // try std.testing.expectEqual(0, r6[0]); // FAILED we get -1
//     // try std.testing.expectEqual(4, r6[1]); // FAILED we get -1
//
//     // Test 7: Bonus character stepback at position 1
//     const input7 = chars.toChars("/abc/def/ghi");
//     const pattern7 = [_]Rune{ 'a', 'g' };
//     const r7 = asciiFuzzyIndex(input7, &pattern7, true);
//     // 'a' at 1, stepback to 0 to include '/'
//     try std.testing.expectEqual(0, r7[0]);
//     try std.testing.expectEqual(10, r7[1]);
//
//     // Test 8: Unicode boundary test (pattern with max ASCII char)
//     const input8 = chars.toChars("test~final");
//     const pattern8 = [_]Rune{ 't', '~', 'f' };  // ~ is ASCII 126
//     const r8 = asciiFuzzyIndex(input8, &pattern8, true);
//     try std.testing.expectEqual(0, r8[0]);
//     try std.testing.expectEqual(6, r8[1]);
// }

// The ultimate stress test
// test "asciiFuzzyIndex pathological" {
//     fuzzyInit("default");
//
//     // Create a string where the pattern chars appear many times
//     var buf: [1000]u8 = undefined;
//     var i: usize = 0;
//
//     // Fill with: "xAxBxCx" repeated
//     while (i < 994) : (i += 7) {
//         buf[i] = 'x';
//         buf[i+1] = 'A';
//         buf[i+2] = 'x';
//         buf[i+3] = 'B';
//         buf[i+4] = 'x';
//         buf[i+5] = 'C';
//         buf[i+6] = 'x';
//     }
//     // End with one more 'C'
//     buf[999] = 'C';
//
//     const input = chars.Chars{ .slice = buf[0..], .is_ascii = true };
//     const pattern = [_]Rune{ 'A', 'B', 'C' };
//
//     const result = asciiFuzzyIndex(input, &pattern, true);
//     // Should find first 'A' at 1, stepback to 0
//     // Should extend to last 'C' at 999
//     try std.testing.expectEqual(0, result[0]);
//     try std.testing.expectEqual(1000, result[1]);
// }

const Chars = chars.Chars;
const expectEqual = std.testing.expectEqual;
const log = std.log;
const chars = @import("chars.zig");
const Slab = @import("slab").Slab;
const std = @import("std");
