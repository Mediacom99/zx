const overflow64: u64 = 0x8080808080808080;
const overflow32: u32 = 0x80808080;

fn isAsciiOptimized(bytes: []const u8) struct { bool, usize } {
    const len = bytes.len;
    var i: usize = 0;

    //Loop over 8 byte chunk
    while (i + 8 <= len) {
        const eight_bytes = @as(*const [8]u8, @ptrCast(bytes[i..i+8].ptr));
        const chunk: u64 = std.mem.readInt(u64, eight_bytes, .little);
        //If not zero it means at least 1 out of 8 bytes is not ascii
        if ((overflow64 & chunk) != 0) {
            return .{ false, i };
        }
        i += 8;
    }

    //Loop over remaining 4 bytes chunk
    while (i + 4 <= len) {
        const four_bytes = @as(*const [4]u8, @ptrCast(bytes[i..i+4].ptr));
        const chunk = std.mem.readInt(u32, four_bytes, .little);
        //If not zero it means at least 1 out of 4 bytes is not ascii
        if ((overflow32 & chunk) != 0) {
            return .{ false, i };
        }
        i += 4;
    }

    //Check single bytes
    while (i < bytes.len) {
        if (!std.ascii.isASCII(bytes[i])) {
            return .{ false, i };
        }
        i += 1;
    }
    return .{ true, 0 };
}

pub const Chars = struct {
    const Self = @This();

    slice: []const u8,
    is_ascii: bool,
    trim_len_known: bool = false,
    trim_len: u16 = 0,

    //TODO: UNDERSTAND THIS
    // XXX Piggybacking item index here is a horrible idea. But I'm trying to
    // minimize the memory footprint by not wasting padded spaces.
    index: u32 = 0,

    /// Wraps byte slice into Chars: if input is only ascii the original slice is used.
    /// If input is not only ascii then every unicode codepoint is stored as i32 type
    /// called Rune.
    /// Chars always contains a []u8 view of the original []i32 slice;
    /// Input is assumed to be valid utf-8 with replacement chars if needed.
    /// Always call deinit in order to free owned runes in case of unicode input.
    pub fn fromBytes(alloc: std.mem.Allocator, bytes: []const u8) !Chars {
        const is_ascii, const ascii_until = isAsciiOptimized(bytes);
        if (is_ascii) {
            return .{ .slice = bytes, .is_ascii = true };
        }

        //Not only ascii, first we append the ascii we have
        var runes = std.ArrayList(Rune).init(alloc);
        errdefer runes.deinit();

        for (0..ascii_until) |i| {
            //Cast ascii byte as i32
            try runes.append(@as(i32, @intCast(bytes[i])));
        }

        // bytes is assumed to be valid utf8 so we can iterate over codepoints
        // FIXME that bytes slice IS WRONG
        var utf8_iter = std.unicode.Utf8Iterator{.bytes = bytes[ascii_until..], .i = 0};
        while(utf8_iter.nextCodepoint()) |codepoint| {
            try runes.append(@intCast(codepoint));
        }

        const runes_owned: []i32 = try runes.toOwnedSlice();

        //This is smart. (All credits goes to fzf).
        //Cast owned runes slice as u8 slice
        const bytes_ptr: [*]u8 = @alignCast(@ptrCast(runes_owned.ptr));
        const bytes_len: usize = runes_owned.len * @sizeOf(i32);
        return .{
            .slice = bytes_ptr[0..bytes_len],
            .is_ascii = false,
        };
    }

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        if (!self.is_ascii) {
            if (self.optional_runes()) |runes| {
                alloc.free(@constCast(runes));
            }
        }
    }

    // casts back from u8 to runes (i32)
    pub fn optional_runes(self: Self) ?[]const Rune {
        if (self.is_ascii) {
            return null;
        }
        const runes_ptr: [*]const Rune = @alignCast(@ptrCast(self.slice.ptr));
        const runes_len = self.slice.len / @sizeOf(i32);
        return runes_ptr[0..runes_len];
    }

    pub fn length(self: Self) usize {
        if (self.optional_runes()) |runes| {
            return runes.len;
        }
        return self.slice.len;
    }
};



// --------- UNIT TESTS ---------

// test "optimized-check-ascii-supereasy" {
//     const chars = @import("chars.zig");
//     const is_ascii, const index = chars.isAsciiFast("Hello World");
//     try std.testing.expect(is_ascii == true);
//     try std.testing.expect(index == 0);
// }
//
// test "optimized-check-ascii-hard" {
//
//     // Large and diverse string for testing
//     const test_string =
//         \\ Hello, World! This is an ASCII test. Everything should work fine.\n
//         \\ Some non-ASCII characters: 你好, 世界! (Chinese)\n
//         \\ This is Cyrillic: Привет мир! (Russian)\n
//         \\ Math symbols: ∆ ∑ √ ± → ≈ (Math symbols)\n
//         \\ Emojis: 😀 😎 👨‍💻 👩‍🔬 (Emojis)\n
//         \\ Random special chars: © ™ ℗ ≠ ⊗ (Special)\n
//         \\ More ASCII: This is just a longer string with ASCII characters like A B C 123!\n
//         \\ Complex sentence with random symbols: @ # $ % ^ & * ( ) _ + = ` ~\n
//         \\ Ending with more mixed: C’est la vie! 这是生活! (French and Chinese)\n
//     ;
//
//     // const start = std.time.nanoTimestamp();
//     const is_ascii, const index = isAsciiFast(test_string);
//     // const nano_elapsed = std.time.nanoTimestamp() - start;
//
//     try std.testing.expect(is_ascii == false);
//     try std.testing.expect(index == 144);
// }

// test "bytes-i32-bytes-toChars" {
//     std.testing.log_level = .debug;
//     const alloc = std.testing.allocator;
//     const input = "hello world";
//     var chars = try Chars.fromBytes(alloc, input);
//     defer chars.deinit(alloc);
//
//     try std.testing.expectEqual(chars.slice.len, @sizeOf(i32)*chars.length());
//     // try std.testing.expect(chars.is_ascii);
//     // try std.testing.expectEqual(input.ptr, chars.slice.ptr);
//     // try std.testing.expectEqual(input.len, chars.slice.len);
//     // try std.testing.expectEqualStrings(input, chars.slice);
// }


test "fromBytes comprehensive Unicode string" {
    const alloc = std.testing.allocator;
    
    const test_unicode = 
        // ASCII start (46 bytes)
        "The quick brown fox jumps over the lazy dog! " ++
        
        // Latin extended (35 bytes - includes multi-byte chars)
        "Café, naïve, résumé, Zürich, señor, " ++
        
        // Greek (35 bytes)
        "Ελληνικά (Greek): Αλφάβητο, " ++
        
        // Cyrillic (47 bytes)
        "Русский язык (Russian): Привет мир! " ++
        
        // Chinese (39 bytes)
        "中文 (Chinese): 你好世界！春夏秋冬，" ++
        
        // Japanese (48 bytes)
        "日本語: ひらがな、カタカナ、漢字、" ++
        
        // Korean (30 bytes)
        "한국어 (Korean): 안녕하세요! " ++
        
        // Arabic (34 bytes)
        "العربية: مرحبا بالعالم! " ++
        
        // Hebrew (26 bytes)
        "עברית: שלום עולם! " ++
        
        // Thai (35 bytes)
        "ภาษาไทย: สวัสดีครับ " ++
        
        // Emojis (49 bytes - 4 bytes each + space)
        "Emojis: 😀😃😄😁🤣😂😊😇🙂🙃😉😌 " ++
        
        // More content...
        "END";
    
    // Process the string
    var chars = try Chars.fromBytes(alloc, test_unicode);
    defer chars.deinit(alloc);
    
    // Basic checks
    try std.testing.expect(!chars.is_ascii);
    
    // Get the runes
    const runes = chars.optional_runes().?;
    
    // Check ASCII part
    try std.testing.expectEqual('T', runes[0]);
    try std.testing.expectEqual('h', runes[1]);
    try std.testing.expectEqual('e', runes[2]);
    try std.testing.expectEqual(' ', runes[3]);
    
    // Find where non-ASCII starts - should be at "Café"
    // The 'é' in Café is at position 49 (after the first sentence + "Caf")
    var ascii_end: usize = 0;
    for (0..runes.len) |i| {
        if (runes[i] > 127) {
            ascii_end = i;
            break;
        }
    }
    
    // The first non-ASCII character should be 'é' (U+00E9)
    try std.testing.expectEqual(0x00E9, runes[ascii_end]);
    
    // Check some specific Unicode characters
    
    // Find "Ελληνικά" - Greek capital epsilon
    var greek_start: ?usize = null;
    for (0..runes.len) |i| {
        if (runes[i] == 0x0395) { // Ε (Greek capital epsilon)
            greek_start = i;
            break;
        }
    }
    try std.testing.expect(greek_start != null);
    
    // Check Greek word "Ελληνικά"
    if (greek_start) |start| {
        try std.testing.expectEqual(@as(i32, 0x0395), runes[start]);     // Ε
        try std.testing.expectEqual(@as(i32, 0x03BB), runes[start + 1]); // λ
        try std.testing.expectEqual(@as(i32, 0x03BB), runes[start + 2]); // λ
        try std.testing.expectEqual(@as(i32, 0x03B7), runes[start + 3]); // η
        try std.testing.expectEqual(@as(i32, 0x03BD), runes[start + 4]); // ν
        try std.testing.expectEqual(@as(i32, 0x03B9), runes[start + 5]); // ι
        try std.testing.expectEqual(@as(i32, 0x03BA), runes[start + 6]); // κ
        try std.testing.expectEqual(@as(i32, 0x03AC), runes[start + 7]); // ά
    }
    
    // Find Chinese "中文"
    var chinese_start: ?usize = null;
    for (0..runes.len) |i| {
        if (runes[i] == 0x4E2D) { // 中
            chinese_start = i;
            break;
        }
    }
    try std.testing.expect(chinese_start != null);
    
    if (chinese_start) |start| {
        try std.testing.expectEqual(0x4E2D, runes[start]);     // 中
        try std.testing.expectEqual(0x6587, runes[start + 1]); // 文
    }
    
    // Find first emoji
    var emoji_start: ?usize = null;
    for (0..runes.len) |i| {
        if (runes[i] == 0x1F600) { // 😀
            emoji_start = i;
            break;
        }
    }
    try std.testing.expect(emoji_start != null);
    
    if (emoji_start) |start| {
        try std.testing.expectEqual(0x1F600, runes[start]);     // 😀
        try std.testing.expectEqual(0x1F603, runes[start + 1]); // 😃
        try std.testing.expectEqual(0x1F604, runes[start + 2]); // 😄
    }
    
    // Check that END is at the end
    const len = runes.len;
    try std.testing.expectEqual('E', runes[len - 3]);
    try std.testing.expectEqual('N', runes[len - 2]);
    try std.testing.expectEqual('D', runes[len - 1]);
}

// test "fromBytes ASCII detection boundary" {
//     const alloc = std.testing.allocator;
//
//     // Test where ASCII ends exactly at a clean boundary
//     const test1 = "Hello World" ++ "世界";
//     var chars1 = try Chars.fromBytes(alloc, test1);
//     defer chars1.deinit(alloc);
//
//     const runes1 = chars1.optional_runes().?;
//     try std.testing.expectEqual(@as(i32, 'H'), runes1[0]);
//     try std.testing.expectEqual(@as(i32, 'd'), runes1[10]);
//     try std.testing.expectEqual(@as(i32, 0x4E16), runes1[11]); // 世
//     try std.testing.expectEqual(@as(i32, 0x754C), runes1[12]); // 界
//
//     // Test starting with non-ASCII
//     const test2 = "世界Hello";
//     var chars2 = try Chars.fromBytes(alloc, test2);
//     defer chars2.deinit(alloc);
//
//     const runes2 = chars2.optional_runes().?;
//     try std.testing.expectEqual(@as(i32, 0x4E16), runes2[0]); // 世
//     try std.testing.expectEqual(@as(i32, 0x754C), runes2[1]); // 界
//     try std.testing.expectEqual(@as(i32, 'H'), runes2[2]);
// }

const std = @import("std");
const Rune = @import("fuzzy.zig").Rune;
const unicode = @import("unicode.zig");
