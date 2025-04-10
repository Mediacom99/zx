//! History service handles loading history data from different shells.

const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;
const utils = @import("utils.zig");

///max non-space bytes hashed to create the key
const keySize: usize = 255;

//Used to prealloacate space for hash maps
const bytesPerLine: usize = 32;

/// ArrayHashMap containing Command structs
hist: CommandList,

alloc: std.mem.Allocator,

cmd_arena: std.heap.ArenaAllocator,

file_path: []const u8 = undefined,

pub const Command = struct {
    /// Actual command with spaces
    command: []const u8 = undefined,
    
    //How many times the command was found in history
    copies: usize = 1,
};

/// Initialize History Service with given history file
pub fn init(alloc: std.mem.Allocator, histfile_path: []const u8) !Self {
    var newSelf = Self{
        .file_path = histfile_path,
        .hist = CommandList.init(alloc),
        .alloc = alloc,
        .cmd_arena = std.heap.ArenaAllocator.init(alloc),
    };
    try newSelf.parseFile(histfile_path);
    return newSelf;
}

/// Frees the array hash map and all keys and values heap allocated.
pub fn deinit(self: *Self) void {
    self.cmd_arena.deinit();
    self.hist.deinit();
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
    
    //TODO do we need this ?
    const metadata = try file.metadata();
    try self.hist.ensureTotalCapacity(@intCast(metadata.size() / bytesPerLine));

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
        //the key is the first KEY_SIZE bytes of cmd that are not spaces
        var keyBuf: [keySize]u8 = undefined;
        var key_len: usize = 0;
        for (0..keySize) |i| {
            if (i == cmd.len) break;
            if (cmd[i] != ' '){ 
                keyBuf[key_len] = cmd[i];
                key_len+=1;
            }
        }
        if (key_len == 0) continue;
        const key = keyBuf[0..key_len];
        //TODO add arraylist with entries to preserve order
        //we use hashmaps only for fast lookups
        const gop = try self.hist.getOrPut(key);
        if (gop.found_existing) {
            gop.value_ptr.copies += 1;
        } else {
            gop.value_ptr.* = .{
                .copies = 1,
                .command = try self.cmd_arena.allocator().dupe(u8, cmd),
            };
        }
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
