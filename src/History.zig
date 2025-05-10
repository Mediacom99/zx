pub const Error = error {
    InvalidFilePath,
    MissingFilePath,
    EmptyFile,
    ParseFailed,
    InitFailed,
    FileTooBigMax100MB,
};

///max non-space bytes hashed to create the key
const key_size: usize = 255;

const max_file_size: usize = 1024 * 1024 * 100; //100MB

//Used to prealloacate space for hash maps
const bytes_per_line: usize = 32;

pub const Command = struct {
    cmd: []const u8,
    reruns: usize = 1,
};

file_path: []const u8 = undefined,

list: List = undefined,

map: Map = undefined,

gpa: Allocator,

arena: std.heap.ArenaAllocator,

/// Initialize History Service with given history file
pub fn init(allocator: Allocator, histfile_path: []const u8) Self {
    return .{
        .file_path = histfile_path,
        .gpa = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .list = List{},
        .map = Map.init(allocator),
    };
}

/// Nodes must be manually freed
pub fn deinit(self: *Self) void {
    self.arena.deinit();
    self.map.deinit();
    return;
}

/// parses history file and loads it into internal hash map.
pub fn parseFile(self: *Self, path: []const u8) !void {
    var file: std.fs.File = undefined;
    if (std.fs.path.isAbsolute(path)) {
        file = try std.fs.openFileAbsolute(path, .{});
    } else {
        file = try std.fs.cwd().openFile(path, .{});
    }
    defer file.close();

    const metadata = try file.metadata();
    const size = metadata.size();
    if (size == 0) { return Error.EmptyFile; }
    if (size > max_file_size) { return Error.FileTooBigMax100MB; }
    var raw_content: []u8 = undefined;
    
    //For linux we map file to memory
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
            return Error.EmptyFile;
        }
        log.debug("Bytes mmapped to virtual mem: {}", .{raw_content.len});
    } else {
            raw_content = try self.gpa.alloc(u8, size);
        const bytes_read = try file.readAll(raw_content);
        if (bytes_read == 0) {
            return Error.ParseFailed;
        }
        log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    }
    defer {
        if (builtin.target.os.tag == .linux) {
            std.posix.munmap(@alignCast(raw_content));
        } else {
           self.gpa.free(raw_content);
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
        const allocator = self.arena.allocator();
        const key = try allocator.dupe(u8, key_buf[0..key_len]);
        if (self.map.get(key)) |node| {
               node.*.data.reruns += 1; 
               self.list.remove(node);
               self.list.append(node);
        } else {
            const cmd_trimmed = try allocator.dupe(u8, std.mem.trim(u8, cmd, " "));
            const new_node = try allocator.create(List.Node);
            const new_cmd = Command{.cmd = cmd_trimmed};
            new_node.data = new_cmd;
            try self.map.putNoClobber(key, new_node);
            self.list.append(new_node);
        }
    }
}

pub fn debugPrintMap(self: *Self) void {
    var val_iter = self.map.valueIterator();
    while(val_iter.next()) |val| {
        std.debug.print("[{d}] {s}\n", .{val.*.data.reruns, val.*.data.cmd});
    }
}

pub fn debugPrintList(self: *Self) void {
    var temp: ?*List.Node = self.list.first;
    while(temp) |node| {
        std.debug.print("[{d}] {s}\n", .{node.data.reruns, node.data.cmd});
        temp = node.next;
    }
}

const Map = std.StringHashMap(*List.Node);
const List = std.DoublyLinkedList(Command);
const Self = @This();
const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const log = std.log;
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
