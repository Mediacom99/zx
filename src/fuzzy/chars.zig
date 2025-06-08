pub const Chars = struct {
    slice: []const u8,
    is_ascii: bool,
    trim_len_known: bool,
    trim_len: u16,

    //TODO: UNDERSTAND THIS
    // XXX Piggybacking item index here is a horrible idea. But I'm trying to
    // minimize the memory footprint by not wasting padded spaces.
    index: u32,
};

const overflow64: u64 = 0x8080808080808080;
const overflow32: u32 = 0x80808080;

fn isAsciiFast(bytes: []const u8) struct {bool, usize} {
    const len = bytes.len;
    var i: usize = 0;

    //Loop over 8 byte chunk
    while (i+8 <= len) {
        const chunk: u64 = @as(u64, bytes[i]);
        //If not zero it means at least 1 out of 8 bytes is not ascii
        if ((overflow64 & chunk) != 0) { 
            return .{false, i};
        }
        i+=8;
    }

    //Loop over remaining 4 bytes chunk
    while (i+4 <= len) {
        const chunk = @as(u32, bytes[i]);
        //If not zero it means at least 1 out of 4 bytes is not ascii
        if ((overflow32 & chunk) != 0) { 
            return .{false, i};
        }
        i+=4;
    }

    //Check single bytes
    while(i < bytes.len) {
        if (!std.ascii.isASCII(bytes[i])) {
            return .{false, i};
        }
        i+=1;
    }
    return .{true, 0};
}

/// Wraps byte slice into Chars
/// Input is already assumed to be valid utf-8.
pub fn toChars(bytes: []const u8) Chars {
    const is_ascii, _ = isAsciiFast(bytes);
    //TODO last three fields are unused
    return .{
        .slice = bytes, 
        .is_ascii = is_ascii, 
        .trim_len_known = false, 
        .trim_len = 0,
        .index = 0,
    };
}

test "optimized-check-ascii-supereasy" {
    const chars = @import("chars.zig");
    const is_ascii, const index = chars.isAsciiFast("Hello World");
    try std.testing.expect(is_ascii == true);
    try std.testing.expect(index == 0);
}

test "optimized-check-ascii-hard" {

    // Large and diverse string for testing
    const test_string =  
        \\ Hello, World! This is an ASCII test. Everything should work fine.\n
        \\ Some non-ASCII characters: 你好, 世界! (Chinese)\n
        \\ This is Cyrillic: Привет мир! (Russian)\n
        \\ Math symbols: ∆ ∑ √ ± → ≈ (Math symbols)\n
        \\ Emojis: 😀 😎 👨‍💻 👩‍🔬 (Emojis)\n
        \\ Random special chars: © ™ ℗ ≠ ⊗ (Special)\n
        \\ More ASCII: This is just a longer string with ASCII characters like A B C 123!\n
        \\ Complex sentence with random symbols: @ # $ % ^ & * ( ) _ + = ` ~\n
        \\ Ending with more mixed: C’est la vie! 这是生活! (French and Chinese)\n
    ;

    // const start = std.time.nanoTimestamp();
    const is_ascii, const index = isAsciiFast(test_string);
    // const nano_elapsed = std.time.nanoTimestamp() - start;

    try std.testing.expect(is_ascii == false);
    try std.testing.expect(index == 144);
}

const std = @import("std");
