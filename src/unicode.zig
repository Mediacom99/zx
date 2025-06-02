// Unicode codepoint is 21bit of information, utf8 can encode that into 1 to 4 bytes like:
// 😀 -> (codepoint) 0x1F600 -> 1110xxx 10xxxxxx 10xxxxxx 10xxxxxx
// https://datatracker.ietf.org/doc/html/rfc3629

pub const Error = error {
    InvalidUtf8
};

const replacement_bytes = &[_]u8{ 0xEF, 0xBF, 0xBD};

/// Allocates memory for a new buffer that will contain utf8 valid codepoints where encountered
/// in buf or the replacement codepoint otherwise.
/// Returned slice must be freed by caller.
pub fn makeValidUtf8FromSlice(alloc: std.mem.Allocator, buf: []const u8) ![]const u8 {
    if (std.unicode.utf8ValidateSlice(buf)) return buf;
    var result = std.ArrayList(u8).init(alloc);
    var pos: usize = 0;
    while (pos < buf.len) {
        const codepoint_len = std.unicode.utf8ByteSequenceLength(buf[pos]) catch |e| {
            //Invalid starting byte
            log.debug("{}", .{e});
            try result.appendSlice(replacement_bytes);
            pos += 1;
            continue;
        };

        //Truncated codepoint
        if (pos + codepoint_len > buf.len) {
            try result.appendSlice(replacement_bytes);
            break;
        }

        //Starting byte is valid
        const slice_to_check = buf[pos..(pos + codepoint_len)];
        const codepoints_in_slice = try std.unicode.utf8CountCodepoints(slice_to_check);
        if (codepoints_in_slice == 0) {
            try result.appendSlice(replacement_bytes);
            pos += codepoint_len;
        }
        if (codepoints_in_slice == 1) {
            try result.appendSlice(slice_to_check);
            pos += codepoint_len;
        }
        for (slice_to_check,1..slice_to_check.len) |b,i| {
            if(std.unicode.utf8ByteSequenceLength(b)) {
                return i;
            } else {
                break;
            }
        }
        //Here the slice_to_check does not have a valid unicode sequence
        //based on the starting byte. We need to skip all bytes until we
        //reach another starting byte.
    }

    log.debug("{s}", .{result.items});
    return result.toOwnedSlice();
}

test "sanitize invalid UTF-8" {

    const invalid_utf8: []const u8 = &[_]u8{
        0x80,       // Lone continuation byte
        0xC0,       // Overlong 2-byte sequence start
        0xC1,       // Overlong 2-byte sequence start
        0xE0, 0x80, 0x80, // Overlong 3-byte sequence for ASCII NUL
        0xF5, 0x80, 0x80, 0x80, // Codepoint above U+10FFFF (invalid in Unicode)
        0xED, 0xA0, 0x80, // UTF-16 surrogate (D800)
        0xF8, 0x88, 0x80, 0x80, 0x80, // 5-byte sequence (not valid in UTF-8)
        0xFC, 0x84, 0x80, 0x80, 0x80, 0x80, // 6-byte sequence (not valid in UTF-8)
        0xFE,       // Invalid byte in UTF-8
        0xFF,       // Invalid byte in UTF-8
        0xE2, 0x28, 0xA1, // Invalid 3-byte sequence (bad continuation)
        0xC3, 0x28, // Invalid 2-byte sequence (bad continuation)
        0xA0,       // Lone continuation byte
        0xE1, 0x80, // Truncated 3-byte sequence
        0xF0, 0x9F, 0x92, // Truncated 4-byte sequence (should be emoji)
        0xF0, 0x28, 0x8C, 0x28, // Invalid 4-byte sequence (bad continuation)
        // Mix in valid ASCII for contrast
        0x61, 0x62, 0x63, // 'a', 'b', 'c'
    };
    const allocator = std.testing.allocator;
    
    const sanitized = try makeValidUtf8FromSlice(allocator, invalid_utf8);
    defer allocator.free(sanitized);

    var expected = std.ArrayList(u8).init(allocator);
    defer expected.deinit();
    for (0..16) |_| {
        try expected.appendSlice(replacement_bytes); // U+FFFD as UTF-8
    }
    try expected.appendSlice("abc");
    
    try std.testing.expectEqualStrings(expected.items, sanitized);
}

const std = @import("std");
const log = std.log;
