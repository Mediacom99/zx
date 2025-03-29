//! History service handles loading history data from different shells.

/// Some message
msg: []const u8 = "Message from HistoryService",

/// file path for history file, defaults: bash -> .bash_history
historyFilePath: []const u8 = undefined,

pub const File = struct {
    buf: []u8 = undefined,
    bytes_read: usize = undefined,
};

/// Initialize History Service
pub fn init() HistoryService {
    return HistoryService{
        .historyFilePath = "/home/mediacom/.bash_history",
    };
}

/// Prints message
pub fn printMsg(self: HistoryService) void {
    log.info("{s}", .{self.msg});
}

/// Get history file as byte buffer of length 10 * 1024 u8
pub fn getHistoryFileBuffer(self: HistoryService) !File {
    const file = std.fs.openFileAbsolute(self.historyFilePath, .{}) catch |err| {
        log.err("cannot open bash history file: {any}", .{err});
        return err;
    };
    defer file.close();
    var fileBuf: [10 * 1024]u8 = undefined;
    const bytesRead = file.readAll(&fileBuf) catch |err| {
        log.err("failed to read file into buffer: {any}", .{err});
        return err;
    };
    log.info("Bytes read: {d}", .{bytesRead});
    return File{
        .buf = &fileBuf,
        .bytes_read = bytesRead,
    };
}

const HistoryService = @This();
const std = @import("std");
const log = std.log;
