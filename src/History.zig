//! History service handles loading history data from different shells.
const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;

/// ArrayHashMap containing Command structs
hist: CommandList,

alloc: std.mem.Allocator,

pub const Command = struct {
    /// timestamp or number
    timestamp: []const u8,
    command: []const u8,
    /// How many times the command appears in history after the first time
    reruns: usize,
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
        try key.resize(replSize);

        //remove spaces
        for (line) |c| {
            if (c != ' ') {
                try key.append(c);
            }
        }
        const res = try self.hist.getOrPut(key.items);
        //if key already exists we increment reruns
        if (res.found_existing == true) {
            res.value_ptr.reruns += 1;
            continue;
        }
        //key doesnt exist, we add one. The variable `cmd` is freed in deinit.
        const cmd = try self.alloc.dupe(u8, line);
        res.value_ptr.command = cmd;
        res.value_ptr.timestamp = "TODO";
        res.value_ptr.reruns = 0;
    }
}

pub fn debugPrint(self: Self) void {
    var it = self.hist.iterator();
    while (it.next()) |e| {
        std.debug.print("{s}({d}) ", .{ e.value_ptr.timestamp, e.value_ptr.reruns });
        std.debug.print("{s}\n", .{e.value_ptr.command});
    }
}
