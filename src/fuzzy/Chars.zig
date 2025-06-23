const Self = @This();
const std = @import("std");
const unicode = @import("unicode.zig");

/// In case of utf8-encoded unicode input this slice is the u8
/// view of an original u21 slice containing all the input's codepoints.
/// If input is only ascii this slice contains each character directly as u8.
slice: []const u8,

is_ascii: bool,

const overflow64: u64 = 0x8080808080808080;
const overflow32: u32 = 0x80808080;
/// Very fast ascii check. Returns whether ascii or not and
/// the index of the first byte from which it is not
/// be possible to tell if the input is ascii.
fn isAsciiOptimized(bytes: []const u8) struct { bool, usize } {
    const len = bytes.len;
    var i: usize = 0;

    //Loop over 8 byte chunk
    while (i + 8 <= len) {
        const eight_bytes = @as(*const [8]u8, @ptrCast(bytes[i .. i + 8].ptr));
        const chunk: u64 = std.mem.readInt(u64, eight_bytes, .little);
        //If not zero it means at least 1 out of 8 bytes is not ascii
        if ((overflow64 & chunk) != 0) {
            return .{ false, i };
        }
        i += 8;
    }

    //Loop over remaining 4 bytes chunk
    while (i + 4 <= len) {
        const four_bytes = @as(*const [4]u8, @ptrCast(bytes[i .. i + 4].ptr));
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

/// Wraps byte slice into Chars: if input is only ascii the original slice is used.
/// If input is not only ascii then every unicode codepoint is stored as u21.
/// Chars always contains a []u8 view of the original []u21 slice in case of unicode.
/// Input is assumed to be valid utf-8 with replacement chars if needed.
/// Always call deinit in order to free owned runes in case of unicode input.
pub fn initFromByteSlice(alloc: std.mem.Allocator, bytes: []const u8) !Self {
    const is_ascii, const ascii_until = isAsciiOptimized(bytes);
    if (is_ascii) {
        return .{ .slice = bytes, .is_ascii = true };
    }

    //Not only ascii, first we append the ascii we have
    var runes = std.ArrayList(u21).init(alloc);
    errdefer runes.deinit();

    for (0..ascii_until) |i| {
        //Cast ascii byte as u21
        try runes.append(bytes[i]);
    }

    // bytes is assumed to be valid utf8 so we can iterate over codepoints
    var utf8_iter = std.unicode.Utf8Iterator{ .bytes = bytes[ascii_until..], .i = 0 };
    while (utf8_iter.nextCodepoint()) |codepoint| {
        try runes.append(codepoint);
    }

    const runes_owned: []u21 = try runes.toOwnedSlice();

    // This is smart. (All credits goes to fzf).
    // Cast owned runes slice as u8 slice
    const bytes_ptr: [*]u8 = @alignCast(@ptrCast(runes_owned.ptr));
    const bytes_len: usize = runes_owned.len * @sizeOf(u21);
    return .{
        .slice = bytes_ptr[0..bytes_len],
        .is_ascii = false,
    };
}

test "initFromByteSlice ascii-only input" {
    const allocator = std.testing.allocator;
    var chars = try Self.initFromByteSlice(allocator, "Hello World!\n\t\r");
    defer chars.deinit(allocator);
    try std.testing.expectEqual(chars.is_ascii, true);
    try std.testing.expectEqual(chars.toCodepoints(), null);
    try std.testing.expectEqual(chars.length(), 15);
}

test "initFromByteSlice comprehensive Unicode string" {
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
    var chars = try Self.initFromByteSlice(alloc, test_unicode);
    defer chars.deinit(alloc);
    try std.testing.expect(!chars.is_ascii);
    const runes = chars.toCodepoints() orelse unreachable;

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
        try std.testing.expectEqual(@as(u21, 0x0395), runes[start]); // Ε
        try std.testing.expectEqual(@as(u21, 0x03BB), runes[start + 1]); // λ
        try std.testing.expectEqual(@as(u21, 0x03BB), runes[start + 2]); // λ
        try std.testing.expectEqual(@as(u21, 0x03B7), runes[start + 3]); // η
        try std.testing.expectEqual(@as(u21, 0x03BD), runes[start + 4]); // ν
        try std.testing.expectEqual(@as(u21, 0x03B9), runes[start + 5]); // ι
        try std.testing.expectEqual(@as(u21, 0x03BA), runes[start + 6]); // κ
        try std.testing.expectEqual(@as(u21, 0x03AC), runes[start + 7]); // ά
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
        try std.testing.expectEqual(0x4E2D, runes[start]); // 中
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
        try std.testing.expectEqual(0x1F600, runes[start]); // 😀
        try std.testing.expectEqual(0x1F603, runes[start + 1]); // 😃
        try std.testing.expectEqual(0x1F604, runes[start + 2]); // 😄
    }

    // Check that END is at the end
    const len = runes.len;
    try std.testing.expectEqual('E', runes[len - 3]);
    try std.testing.expectEqual('N', runes[len - 2]);
    try std.testing.expectEqual('D', runes[len - 1]);
}

/// Detects if input is unicode and only in that case
/// it frees the internal slice. For ascii input
/// no other allocation was done by Chars because each
/// original byte was enough to store the input, so
/// there is nothing to free.
pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (!self.is_ascii) {
        if (self.toCodepoints()) |runes| {
            alloc.free(@constCast(runes));
        }
    }
}

/// Casts back from u8 to original codepoint (u21) slice.
/// Returns null if internal slice is ascii only.
pub fn toCodepoints(self: Self) ?[]const u21 {
    if (self.is_ascii) {
        return null;
    }
    const codepoints_ptr: [*]const u21 = @alignCast(@ptrCast(self.slice.ptr));
    const codepoints_len = self.slice.len / @sizeOf(u21);
    return codepoints_ptr[0..codepoints_len];
}

test "optional_runes with unicode input" {
    const allocator = std.testing.allocator;
    var chars = try Self.initFromByteSlice(
        allocator,
        "😀🤣😊",
    );
    defer chars.deinit(allocator);
    try std.testing.expectEqualDeep(
        chars.toCodepoints(),
        &[_]u21{
            '😀', '🤣', '😊',
        },
    );
}

/// Returns number of runes for unicode
/// input or length of internal slice for
/// ascii input.
pub fn length(self: Self) usize {
    if (self.toCodepoints()) |cps| {
        return cps.len;
    }
    return self.slice.len;
}

pub fn get(self: Self, index: usize) u21 {
    if (self.toCodepoints()) |cps| {
        return cps[index];
    }
    return self.slice[index];
}

test "chars get rune at index and length of input" {
    const allocator = std.testing.allocator;
    var chars = try Self.initFromByteSlice(allocator, "Hello 🤣");
    defer chars.deinit(allocator);
    try std.testing.expectEqual(chars.length(), 7);
    try std.testing.expectEqual(chars.get(0), 'H');
    try std.testing.expectEqual(chars.get(1), 'e');
    try std.testing.expectEqual(chars.get(6), '🤣');
}
