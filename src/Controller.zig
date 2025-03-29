//! Controller handles application logic, only one that can access HistoryService.
//!

/// Some message for testing
msg: []const u8 = "Message from Controller",

/// HistoryService instance
var hist: HistoryService = undefined;

/// Initialize controller
pub fn init() Ctrl {
    hist = HistoryService.init();
    return Ctrl{};
}

/// Print message
pub fn printMsg(self: Ctrl) void {
    hist.printMsg();
    log.info("{s}", .{self.msg});
}

/// Do something
pub fn doSmth(_: Ctrl) !void {
    const file = hist.getHistoryFileBuffer() catch |err| {
        return err;
    };
    const stdout = std.io.getStdOut();
    const cutFileBuf: []u8 = file.buf[(file.bytes_read - 101)..(file.bytes_read - 1)];
    _ = try stdout.write(cutFileBuf);
    _ = try stdout.write("\n");
}

const Ctrl = @This();
const HistoryService = @import("HistoryService.zig");
const log = std.log;
const std = @import("std");
