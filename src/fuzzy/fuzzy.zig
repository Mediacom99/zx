//! Zig implementation of fzf V1 and V2 fuzzy matching algorithms.
//! https://github.com/junegunn/fzf

const Chars = @import("Chars.zig");
const expectEqual = std.testing.expectEqual;
const log = std.log;
const std = @import("std");
const normalizeRune = @import("../unicode/normalize.zig").normalizeRune;
const unicode = @import("../unicode/unicode.zig");

/// Match result
pub const Result = struct {
    start: ?u21, // null no match
    end: ?u21, // null for no match
    score: i32, // 0 for no match, can be negative in some cases

    /// Start = end = null; score = 0
    pub fn noMatch() Result {
        return .{ .start = null, .end = null, .score = 0 };
    }

    pub fn isMatch(self: Result) bool {
        return self.start != null;
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
fn trySkip(input: Chars, case_sensitive: bool, pattern_byte: u8, from: usize) ?usize {
    var byte_array = input.slice[from..];
    if (std.mem.indexOf(u8, byte_array, &[_]u8{pattern_byte})) |index_found| {
        if (index_found == 0) {
            //Cant skip any further
            return from;
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
        return from + idx;
    }
    return null;
}

test "trySkip-case-sensitive" {
    fuzzyInit("default");
    const alloc = std.testing.allocator;
    const input = try Chars.initFromByteSlice(alloc, "foobar");

    try std.testing.expectEqual(3, trySkip(input, true, 'b', 0));
    try std.testing.expectEqual(null, trySkip(input, true, 'b', 4));

    const input2 = try Chars.initFromByteSlice(alloc, "fooBar");

    try std.testing.expectEqual(null, trySkip(input2, true, 'b', 0));
}

test "trySkip-case-insensitive" {
    fuzzyInit("default");
    const alloc = std.testing.allocator;

    const input1 = try Chars.initFromByteSlice(alloc, "fooobar");
    try std.testing.expectEqual(4, trySkip(input1, false, 'b', 0));

    const input2 = try Chars.initFromByteSlice(alloc, "fooBabarbarBr");
    try std.testing.expectEqual(3, trySkip(input2, false, 'b', 0));

    const input3 = try Chars.initFromByteSlice(alloc, "aBbcd");
    try std.testing.expectEqual(1, trySkip(input3, false, 'b', 0));

    try std.testing.expectEqual(2, trySkip(input3, false, 'b', 2));
}

/// Computes min and max index which delimit the slice of input that might contain the match.
/// It's an optimization in case of ascii only. The goal is to narrow down the scope
/// onto which to apply the actual matching algorithm.
/// Returns start index and end index + 1 of the new scope.
fn asciiFuzzyIndex(input: Chars, pattern: []const u21, case_sensitive: bool) struct { ?usize, ?usize } {
    // Not possible because input is not ascii only
    if (!input.is_ascii) {
        return .{ 0, input.slice.len };
    }

    //Not possible because pattern is not ascii only.
    for (pattern) |b| {
        const byte: u8 = @intCast(b);
        if (!std.ascii.isAscii(byte)) {
            return .{ null, null };
        }
    }

    //Both pattern and input are ascii only
    var first_idx: usize = 0;
    var idx: usize = 0;
    var last_idx: usize = 0;
    var byte: u8 = undefined;
    for (0..pattern.len) |pidx| {
        //We know pidx to be ascii so u8 is fine
        byte = @intCast(pattern[pidx]);
        if (trySkip(input, case_sensitive, byte, idx)) |i| {
            idx = i;
        } else {
            return .{ null, null };
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
    const scope = input.slice[last_idx..];
    var offset: usize = scope.len - 1;
    while (offset > 0) : (offset -= 1) {
        if (scope[offset] == byte or scope[offset] == bu) {
            return .{ first_idx, last_idx + offset + 1 };
        }
    }
    return .{ first_idx, last_idx + 1 };
}

fn indexAt(index: usize, max: usize, forward: bool) usize {
    if (forward) {
        return index;
    }
    return max - index - 1;
}

//TODO check use of subtraction with usize indexing
fn fuzzyMatchV1(
    case_sensitive: bool,
    normalize: bool,
    forward: bool, //If true start matching from beginning, otherwise from end
    text: Chars,
    pattern: []const u21,
    //with_pos_alloc: ?std.mem.Allocator,
    // ) struct { Result, ?[]u21 } {
) struct { ?usize, ?usize } {
    if (pattern.len == 0) {
        // return .{ Result{ .start = 0, .end = 0, .score = 0 }, null };
        return .{ null, null };
    }

    // Narrow search scope
    const start_idx, _ = asciiFuzzyIndex(text, pattern, case_sensitive);
    if (start_idx == null) {
        // return .{ Result.noMatch(), null };
        return .{ null, null };
    }

    var pidx: usize = 0; //pattern index
    var sidx: ?usize = null; //start index of match in text
    var eidx: ?usize = null; //end index of match in text

    const len_runes = text.length();
    const len_pattern = pattern.len;

    //Loop over number of runes
    for (0..len_runes) |index| {
        var char: u21 = text.get(indexAt(index, len_runes, forward));
        if (!case_sensitive) {
            //TODO
            if (char >= 'A' and char <= 'Z') {
                char += 32; // lowercase char
            } else if (char > MAX_ASCII) {
                char = unicode.toLower(char);
            }
            @panic("TODO!");
        }

        if (normalize) {
            char = normalizeRune(char);
        }

        const pchar: u21 = pattern[indexAt(pidx, len_pattern, forward)];
        if (char == pchar) {
            if (sidx == null) {
                sidx = index;
            }
            pidx += 1;
            if (pidx == len_pattern) {
                eidx = index + 1;
                break;
            }
        }
    }

    // we proceed with backward scan
    if (sidx != null and eidx != null) {
        pidx -= 1;
        var index = eidx.? - 1;
        while (index >= sidx.?) : (index -= 1) {
            const tidx = indexAt(index, len_runes, forward);
            var char = text.get(tidx);
            if (!case_sensitive) {
                //TODO
                @panic("TODO");
            }
            if (normalize) char = normalizeRune(char);

            const pidx_ = indexAt(pidx, len_pattern, forward);
            const pchar = pattern[pidx_];
            if (char == pchar) {
                if (pidx == 0) {
                    sidx = index;
                    break;
                } else {
                    pidx -= 1;
                }
            }
        }

        if (!forward) {
            sidx = len_runes - eidx.?;
            eidx = len_runes - sidx.?;
        }

        // const score, const pos = calculateScore(
        //     with_pos_alloc,
        //     case_sensitive,
        //     normalize,
        //     text,
        //     pattern,
        //     sidx,
        //     eidx,
        // );
        return .{ sidx, eidx };
    }

    // return .{ Result.noMatch(), null };
    return .{ null, null };
}

test "V1 fuzzy algorith, start and end index" {
    std.testing.log_level = .debug;
    fuzzyInit("default");
    const alloc = std.testing.allocator;
    const text = "ABC_abc😀ask⅕⅙⅐ḥḫ🤣😊a sdkj sa9 ((( AS:ASL DKD WEP AS)))";
    const pattern = [_]u21{ '😀', '⅕', '🤣' };
    var input = try Chars.initFromByteSlice(alloc, text);
    defer input.deinit(alloc);
    const sidx, const eidx = fuzzyMatchV1(
        true,
        false,
        true,
        input,
        &pattern,
    );

    try expectEqual(sidx != null, true);
    try expectEqual(eidx != null, true);

    const cp = input.toCodepoints().?;
    const match = try unicode.utf8EncodeSlice(alloc, cp[sidx.?..eidx.?]);
    defer alloc.free(match);

    try std.testing.expectEqualDeep("😀ask⅕⅙⅐ḥḫ🤣", match);
    try expectEqual(sidx.?, 7);
    try expectEqual(eidx.?, 17);
}
