//! History service handles loading history data from different shells.
const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;
const utils = @import("utils.zig");

///max (non space) command chars hashed to create the key
const KEY_SIZE: usize = 255;

/// ArrayHashMap containing Command structs
hist: CommandList,

alloc: std.mem.Allocator,

pub const Command = struct {
    /// Actual command with spaces
    command: []const u8 = undefined,
    
    //How many times the command was found in history
    copies: usize = 1,
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


/// parses history file and loads it into internal hash map.
fn parseHistoryFile(self: *Self, historyFilePath: []const u8) !void {
    var file = try std.fs.openFileAbsolute(historyFilePath, .{});
    defer file.close();

    //TODO use stack for common bash history file size, heap otherwise
    const end_pos = try file.getEndPos();
    var content = try std.ArrayList(u8).initCapacity(self.alloc, end_pos);
    defer content.deinit();
    try content.resize(end_pos);

    const bytes_read = try file.readAll(content.items);
    log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    if (bytes_read <= 0) {
        return error.EmptyHistoryFile;
    }
    utils.sanitizeAscii(&content);

    //FIXME need this?
    const contentTrimmed = std.mem.trim(u8, content.items, "\n"); 
    var iter = std.mem.splitScalar(u8, contentTrimmed, '\n');
    while(iter.next()) |cmd| {
        //the key is made up of the first KEY_SIZE chars of cmd that are not spaces
        var keyBuf: [KEY_SIZE]u8 = undefined;
        var key_len: usize = 0;
        for (0..KEY_SIZE) |i| {
            if (i == cmd.len) break;
            if (cmd[i] != ' '){ 
                keyBuf[key_len] = cmd[i];
                key_len+=1;
            }
        }
        if (key_len == 0) continue;
        const key = keyBuf[0..key_len];
        var new_cmd = Command{};
        if (self.hist.fetchOrderedRemove(key)) |kv| {
            new_cmd.command = kv.value.command;
            new_cmd.copies = kv.value.copies + 1;
        } else {
            const notOwnedCmd = try self.alloc.dupe(u8, cmd);
            new_cmd.command = notOwnedCmd;
        }
        try self.hist.putNoClobber(key, new_cmd);
    }
}

pub fn debugPrint(self: Self) void {
    var it = self.hist.iterator();
    while (it.next()) |e| {
        std.debug.print("[{d}] {s}\n", .{ e.value_ptr.copies, e.value_ptr.command });
    }
}

pub fn debugPrintHashes(self: Self) void {
    const hashes = self.hist.unmanaged.entries.items(.hash);
    for (hashes) |hash| {
        std.debug.print("0x{x}\n", .{hash});
    }
}
