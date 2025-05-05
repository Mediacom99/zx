//! History service handles loading history data from different shells. It's the middleman
//! between the App instance and the backing store (LinkedHash and/or whatever else) that actually
//! handles parsing and loading the data into memory with the appropriate data structures.

const Self = @This();
const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const log = std.log;
const utils = @import("utils.zig");
const linked_hash = @import("LinkedHash.zig");
pub const LinkedHash = linked_hash.LinkedHash([]const u8, []const u8, std.hash_map.StringContext);
const Allocator = std.mem.Allocator;

///max non-space bytes hashed to create the key
const key_size: usize = 255;

//Used to prealloacate space for hash maps
const bytes_per_line: usize = 32;

file_path: []const u8 = undefined,

store: LinkedHash = undefined,

alloc: Allocator,

arena: std.heap.ArenaAllocator,

pub const HistoryError = error {
    InvalidFilePath,
    EmptyHistoryFile,
    FailedToParseFile,
};

/// Initialize History Service with given history file
pub fn init(alloc: Allocator, histfile_path: []const u8) HistoryError!Self {
    var newSelf = Self{
        .file_path = histfile_path,
        .alloc = alloc,
        .arena = std.heap.ArenaAllocator.init(alloc),
        .store = LinkedHash.init(alloc),
    };
    newSelf.parseFile(histfile_path) catch |err| switch(err) {
        HistoryError.EmptyHistoryFile => return HistoryError.EmptyHistoryFile,
        else => {
            log.debug("Failed to parse file: {}", .{err});
            return HistoryError.FailedToParseFile;
        }
    };
    return newSelf;
}

pub fn deinit(self: *Self) void {
    self.store.deinit();
    self.arena.deinit();
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
    
    const md = try file.metadata();
    const size = md.size();
    if (size == 0) {
        return HistoryError.EmptyHistoryFile;
    }
    var raw_content: []u8 = undefined;
    if(builtin.target.os.tag == .linux) {
        raw_content = try std.posix.mmap(
            null,
            size, 
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{.TYPE = .PRIVATE},
            file.handle,
            0
        );
        if (raw_content.len == 0) {
            return HistoryError.EmptyHistoryFile;
        }
        log.debug("Bytes mmapped to virtual mem: {}", .{raw_content.len});
    } else {
        raw_content = try self.alloc.alloc(u8, size);
        const bytes_read = try file.readAll(raw_content);
        if (bytes_read == 0) {
            return HistoryError.FailedToParseFile;
        }
        log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    }
    defer {
        if (builtin.target.os.tag == .linux) {
            std.posix.munmap(@alignCast(raw_content));
        } else {
           self.alloc.free(raw_content);
        }
    }
    assert(raw_content.len == size);
    const new_size = utils.sanitizeAscii(raw_content);

    //FIXME need this?
    const content_trimmed = std.mem.trim(u8, raw_content[0..new_size], "\n"); 

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
        const cmd_trimmed = std.mem.trim(u8, cmd, " "); 
        const arena_alloc = self.arena.allocator();
        const cmd_ptr = try arena_alloc.dupe(u8, cmd_trimmed);
        const key_ptr = try arena_alloc.dupe(u8, key_buf[0..key_len]);
        try self.store.appendUniqueWithArena(key_ptr, cmd_ptr);
    }
}
