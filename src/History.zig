//! History service handles loading history data from different shells.

historyFilePath: []const u8,

/// ArrayHashMap containing Command structs
hist: CommandList,

pub const Command = struct {
    /// null terminated string that holds command with whitespaces
    command: []const u8,
    /// timestamp or number
    timestamp: []const u8,
};

/// Initialize History Service with given history file
pub fn init(alloc: std.mem.Allocator, historyFilePath: []const u8) Self {
    return Self{
        .historyFilePath = historyFilePath,
        .hist = CommandList.init(alloc),
    };
}

/// Frees the array hash map and keys and values if necessary
pub fn deinit(self: *Self) void {
    //K and V heap allocated must be manually freed here.
    self.hist.deinit();
}

pub fn loadAndParseHistoryFile(self: *Self) !void {
    const file = std.fs.openFileAbsolute(self.historyFilePath, .{}) catch |err| {
        log.err("failed to open history file: {any}", .{err});
        return err;
    };
    defer file.close();
    var buf: [10 * 1024]u8 = undefined;
    const bytes_read = file.readAll(&buf) catch |err| {
        log.err("failed to read history file into buffer: {any}", .{err});
        return err;
    };
    log.info("history file: {s} loaded, bytes read: {d}", .{ self.historyFilePath, bytes_read });
    if (bytes_read <= 0) {
        return error.EmptyHistoryFile;
    }

    var iterator = std.mem.splitScalar(u8, buf[0 .. bytes_read - 1], '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        log.info("{s}", .{line});
    }
}

const Key = []const u8;
const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;
