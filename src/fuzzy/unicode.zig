const std = @import("std");
const log = std.log;

pub const Error = error{
    FailedSanitization,
    EmptyByteSlice,
    InvalidUtf8,
};

//TODO: add support for graphemes cluster

/// Formats an array of bytes into valid utf8 by replacing
/// every invalid utf8 sequence using the
/// replacement codepoint 0xFFFD following unicode's 'Substitution of Maximal Subparts', thus
/// it consumes only the bytes for the longest invalid sequence.
/// The sanitization algorithm follows: https://encoding.spec.whatwg.org/#utf-8-decoder
/// Caller owns returned memory.
pub fn sanitizeUtf8UnmanagedStd(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = std.ArrayList(u8).init(alloc);
    const formatter = std.unicode.fmtUtf8(input);
    formatter.format("", .{}, output.writer()) catch |e| {
        log.debug("failed to sanitize utf8 input: {}", .{e});
        return Error.FailedSanitization;
    };
    // log.debug("Input len: {d}", .{input.len});
    // log.debug("Output len: {d}", .{output.items.len});
    return try output.toOwnedSlice();
}

/// Encodes a slice of valid unicode codepoints into valid utf8 slice.
/// No check is perfmored on the validity of codepoints.
/// Preallocates 4 bytes per codepoint to avoid resizing in loop.
/// Caller owns returned memory.
pub fn utf8EncodeSlice(alloc: std.mem.Allocator, codepoints: []const u21) ![]u8 {
    var utf8_buffer = std.ArrayList(u8).init(alloc);
    errdefer utf8_buffer.deinit();

    //Assume worst case scenario, every codepoint is 4 bytes
    try utf8_buffer.ensureTotalCapacityPrecise(codepoints.len * 4);

    for (codepoints) |cp| {
        var temp_bytes: [4]u8 = undefined;
        const nbytes = std.unicode.utf8Encode(
            cp,
            temp_bytes[0..],
        ) catch |e| {
            log.debug("Invalid codepoint: {}", .{e});
            return e;
        };
        utf8_buffer.appendSliceAssumeCapacity(temp_bytes[0..nbytes]);
    }
    return utf8_buffer.toOwnedSlice();
}
