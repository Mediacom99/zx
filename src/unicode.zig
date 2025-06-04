pub const Error = error {
    FailedSanitization,
};

// Formats an array of bytes into valid utf8 by replacing every invalid utf8 sequence using the
// replacement codepoint 0xFFFD following unicode's 'Substitution of Maximal Subparts', thus
// it consumes only the bytes for the longest invalid sequence.
// The sanitization algorithm follows: https://encoding.spec.whatwg.org/#utf-8-decoder
// Output slice needs to be freed by caller.
pub fn sanitizeUtf8UnmanagedStd(alloc: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = std.ArrayList(u8).init(alloc);
    const formatter = std.unicode.fmtUtf8(input);
    formatter.format("", .{}, output.writer()) catch |e| {
        log.debug("failed to sanitize utf8 input: {}", .{e});
        return Error.FailedSanitization;
    };
    log.debug("Input len: {d}", .{input.len});
    log.debug("Output len: {d}", .{output.items.len});
    return try output.toOwnedSlice();
}

// \\Codepoint found: {u}
// \\  Code:           U+{X:0>4}
// \\  Consumed bytes: {d}
// \\  Offset:         {d}
// \\

const std = @import("std");
const log = std.log;
