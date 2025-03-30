//! History service handles loading history data from different shells.
const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;

/// ArrayHashMap containing Command structs
hist: CommandList,

alloc: std.mem.Allocator,

pub const Command = struct {
    /// Actual command with spaces
    command: []const u8 = undefined,

    timestamp: []const u8 = undefined,

    //How many times the command was found in history
    reruns: usize = 1,
};

/// Initialize History Service with given history file
pub fn init(alloc: std.mem.Allocator, historyFilePath: []const u8) !Self {
    var newSelf = Self{
        .hist = CommandList.init(alloc),
        .alloc = alloc,
    };
    try newSelf.parseHistoryFile(historyFilePath);
    return newSelf;
}

/// Frees the array hash map and keys and values if necessary
pub fn deinit(self: *Self) void {
    var it = self.hist.iterator();
    while (it.next()) |e| {
        self.alloc.free(e.value_ptr.command);
    }
    self.hist.deinit();
}

//parses bash history file. The file is always closed.
fn parseHistoryFile(self: *Self, historyFilePath: []const u8) !void {
    var file = try std.fs.openFileAbsolute(historyFilePath, .{});
    defer file.close();

    const end_pos = try file.getEndPos();
    //TODO use stack for common bash history file size, heap otherwise
    const buf = try self.alloc.alloc(u8, end_pos);
    defer self.alloc.free(buf);

    const bytes_read = try file.readAll(buf);
    log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    if (bytes_read <= 0) {
        return error.EmptyHistoryFile;
    }

    // temp buffer
    // ArrayList overhead is usually 24 bytes said Claude, so...
    var key = std.ArrayList(u8).init(self.alloc);
    defer key.deinit();

    // iterator over lines split by newline
    var iterator = std.mem.splitScalar(u8, buf[0..bytes_read], '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;

        //Find size of line without spaces
        const replSize = std.mem.replacementSize(u8, line, " ", "");
        key.clearRetainingCapacity();
        try key.ensureTotalCapacityPrecise(replSize);

        //remove spaces
        for (line) |c| {
            if (c != ' ') {
                key.appendAssumeCapacity(c);
            }
        }

        var new_cmd = Command{ .timestamp = "" }; //TODO add timestamp

        //if key already exists remove old one and reinsert it.
        if (self.hist.fetchOrderedRemove(key.items)) |kv| {
            new_cmd.command = kv.value.command;
            new_cmd.reruns = kv.value.reruns + 1;
            try self.hist.put(kv.key, new_cmd);
        } else {
            new_cmd.command = try self.alloc.dupe(u8, line);
            try self.hist.put(key.items, new_cmd);
        }
    }
}

pub fn debugPrint(self: Self) void {
    var it = self.hist.iterator();
    while (it.next()) |e| {
        std.debug.print("{s}({d}) ", .{ e.value_ptr.timestamp, e.value_ptr.reruns });
        std.debug.print("{s}\n", .{e.value_ptr.command});
    }
}
