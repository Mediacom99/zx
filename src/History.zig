//! History service handles loading history data from different shells. It's the middleman
//! between the App instance and the backing store (LinkedHash and/or whatever else) that actually
//! handles parsing and loading the data into memory with the appropriate data structures.

const Self = @This();
const std = @import("std");
const log = std.log;
const utils = @import("utils.zig");
const linked_hash = @import("LinkedHash.zig");
const LinkedHash = linked_hash.LinkedHash([]const u8, []const u8, std.hash_map.StringContext);
const Allocator = std.mem.Allocator;

///max non-space bytes hashed to create the key
const key_size: usize = 255;

//Used to prealloacate space for hash maps
const bytes_per_line: usize = 32;

file_path: []const u8 = undefined,

store: LinkedHash = undefined,

alloc: Allocator,

arena: *std.heap.ArenaAllocator,

/// Initialize History Service with given history file
pub fn init(alloc: Allocator, arena: *std.heap.ArenaAllocator, histfile_path: []const u8) !Self {
    var newSelf = Self{
        .file_path = histfile_path,
        .alloc = alloc,
        .arena = arena,
        .store = LinkedHash.init(alloc, arena),
    };
    try newSelf.parseFile(histfile_path);
    return newSelf;
}

pub fn deinit(self: *Self) void {
    self.store.deinit();
    return;
}

/// parses history file and loads it into internal hash map.
fn parseFile(self: *Self, path: []const u8) !void {
    var file: std.fs.File = undefined;
    if (std.fs.path.isAbsolute(path)) {
        file = try std.fs.openFileAbsolute(path, .{});
    } else {
        file = try std.fs.cwd().openFile(path, .{});
    }
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
    const content_trimmed = std.mem.trim(u8, content.items, "\n"); 

    var iter = std.mem.splitScalar(u8, content_trimmed, '\n');
    while(iter.next()) |cmd| {
        //the key is the first KEY_SIZE bytes of cmd that are not spaces
        var key_buf: [key_size]u8 = undefined;
        var key_len: usize = 0;
        for (0..key_size) |i| {
            if (i == cmd.len) break;
            if (cmd[i] != ' '){ 
                key_buf[key_len] = cmd[i];
                key_len+=1;
            }
        }
        if (key_len == 0) continue;
        const arena_alloc = self.arena.allocator();
        const cmd_trimmed = std.mem.trim(u8, cmd, " "); 
        const cmd_ptr = try arena_alloc.dupe(u8, cmd_trimmed);
        const key_ptr = try arena_alloc.dupe(u8, key_buf[0..key_len]);
        try self.store.appendUniqueWithArena(key_ptr, cmd_ptr);
    }
}
