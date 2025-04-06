//! History service handles loading history data from different shells.
const CommandList = std.array_hash_map.StringArrayHashMap(Command);
const Self = @This();
const std = @import("std");
const log = std.log;
const sanitizer = @import("sanitizer.zig");

const KEY_SIZE = 255;

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
    //get hist file handle
    var file = try std.fs.openFileAbsolute(historyFilePath, .{});
    defer file.close();

    //TODO use stack for common bash history file size, heap otherwise
    const end_pos = try file.getEndPos();
    const content = try self.alloc.alloc(u8, end_pos);
    defer self.alloc.free(content);

    // read file in buf arraylist
    const bytes_read = try file.readAll(content);
    log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    if (bytes_read <= 0) {
        return error.EmptyHistoryFile;
    }
    const buf = std.mem.trim(u8, content, "\n");
    //TODO add file sanitization

    // const replSize = std.mem.replacementSize(u8, buf, " ", "");
    // const bufNoSpaces = try self.alloc.alloc(u8, replSize);
    // defer self.alloc.free(bufNoSpaces);

    // const replaced = std.mem.replace(u8, buf, " ", "", bufNoSpaces);
    // log.debug("Spaces replaced: {d}", .{replaced});

    var iter = std.mem.splitScalar(u8, buf, '\n');
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
        const key = keyBuf[0..key_len];
        
        log.debug("Key: {s}", .{key});
        log.debug("Cmd: {s}\n", .{cmd});
        //create cmd with cmd timestamp
        //fetchOrderderdRemove from hash map
        //if does NOT already exists, dupe the line, (free it in deinit)
        //otherwise reinsert a new kv pair with same old command address (free in deinit)
    }

}

/// debug function: prints all values formatted
pub fn debugPrint(self: Self) void {
    var it = self.hist.iterator();
    while (it.next()) |e| {
        std.debug.print("{s}({d}) ", .{ e.value_ptr.timestamp, e.value_ptr.reruns });
        std.debug.print("{s}\n", .{e.value_ptr.command});
    }
}

/// debug function: prints all key hashes
pub fn debugPrintHashes(self: Self) void {
    const hashes = self.hist.unmanaged.entries.items(.hash);
    for (hashes) |hash| {
        std.debug.print("0x{x}\n", .{hash});
    }
}
