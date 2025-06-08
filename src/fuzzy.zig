//! Zig implementation of fzf V1 and V2 fuzzy matching algorithms.
//! https://github.com/junegunn/fzf

/// Match result
pub const Result = struct {
    start: i32, // -1 no match
    end: i32, // -1 no match
    score: i32, // 0 for no match, can be negative in some cases

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
const MAX_CHAR_CLASS = @intFromEnum(CharClass.number);
const MAX_ASCII: usize = 127;

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

var initial_char_class = CharClass.white;

// Ascii optimization table (maps each ascii to its CharClass)
var ascii_char_classes: [MAX_ASCII + 1]CharClass = undefined;

// Lookup table where bonus_matrix[prev][curr] gives bonus score without calling bonusFor
var bonus_matrix: [MAX_CHAR_CLASS + 1][MAX_CHAR_CLASS + 1]i16 = undefined;

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
pub fn init(scheme: []const u8) void {
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

test "init-fuzzy" {
    const fuzzy = @import("fuzzy.zig");
    fuzzy.init("default");
    std.debug.print("Bonus matrix:\n", .{});
    for (0..MAX_CHAR_CLASS + 1) |i| {
        for (0..MAX_CHAR_CLASS + 1) |j| {
            std.debug.print("{d} ", .{bonus_matrix[i][j]});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("Ascii lookup table:\n", .{});
    for (ascii_char_classes) |class| {
        std.debug.print("{s} ", .{@tagName(class)});
    }
}

const log = std.log;
const std = @import("std");
