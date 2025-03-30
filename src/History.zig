//! History service handles loading history data from different shells.

/// ArrayHashMap containing Command structs
hist: CommandList,

alloc: std.mem.Allocator,

pub const Command = struct {
    /// timestamp or number
    timestamp: []const u8,
    command: []const u8,
    /// How many times the command appears in history after the first time
    copies: usize,
};

/// Initialize History Service with given history file
pub fn init(alloc: std.mem.Allocator) Self {
    return Self{
        .hist = CommandList.init(alloc),
        .alloc = alloc,
    };
}

/// Frees the array hash map and keys and values if necessary
pub fn deinit(self: *Self) void {
    //Free heap allocated values
    var it = self.hist.iterator();
    while (it.next()) |e| {
        self.alloc.free(e.value_ptr.command);
        self.alloc.free(e.key_ptr.*);
    }
    self.hist.deinit();
}

//parses bash history file. The file is always closed.
pub fn parseHistoryFile(self: *Self, historyFilePath: []const u8) !void {
    var file = try std.fs.openFileAbsolute(historyFilePath, .{});
    defer file.close();

    const end_pos = try file.getEndPos();
    const buf = try self.alloc.alloc(u8, end_pos);
    defer self.alloc.free(buf);

    const bytes_read = try file.readAll(buf);
    log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    if (bytes_read <= 0) {
        return error.EmptyHistoryFile;
    }

    // iterator over lines split by newline
    var iterator = std.mem.splitScalar(u8, buf, '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        const cmd = try self.alloc.dupe(u8, line);

        //Find size of line without spaces
        const replSize = std.mem.replacementSize(u8, line, " ", "");
        const key = try self.alloc.alloc(u8, replSize);

        // trim spaces and put them in key
        _ = std.mem.replace(u8, line, " ", "", key);

        //if key does not already exist we need to update the value, otherwise
        //we update the copies counter
        const res = self.hist.getOrPut(key) catch |err| {
            log.err("self.hist.getOrPut failed: {any}", .{err});
            self.alloc.free(key);
            self.alloc.free(cmd);
            continue;
        };
        if (res.found_existing == true) {
            res.value_ptr.copies += 1;
            self.alloc.free(key);
            self.alloc.free(cmd);
            continue;
        }
        res.value_ptr.command = cmd;
        res.value_ptr.timestamp = "2006";
        res.value_ptr.copies = 0;
    }
}

const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;
