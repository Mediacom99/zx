pub const Error = error {
    EmptyFile,
    FileTooBig_Max50MB,
};

///max non-space bytes hashed to create the key
const KEY_SIZE: usize = 256;

const MAX_FILE_SIZE: usize = 512 * 1024 * 100; //50MB

pub const Command = struct {
    cmd: []const u8,
    reruns: usize = 1,
};

file_path: []const u8 = undefined,

list: List = undefined,

map: Map = undefined,

gpa: Allocator,

arena: Allocator,

pub fn init(allocator: Allocator, arena: Allocator, histfile_path: []const u8) Self {
    return .{
        .file_path = histfile_path,
        .gpa = allocator,
        .arena = arena,
        .list = List{},
        .map = Map.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.map.deinit();
    return;
}

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
    if (size > MAX_FILE_SIZE) { return Error.FileTooBig_Max50MB; }

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
            return Error.EmptyFile;
        }
        log.debug("Bytes mmapped to virtual mem: {}", .{raw_content.len});
    } else {
        raw_content = try self.gpa.alloc(u8, size);
        const bytes_read = try file.readAll(raw_content);
        if (bytes_read == 0) {
            return Error.EmptyFile;
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

    const new_size = ascii.sanitizeAscii(raw_content);
    
    var iter = std.mem.splitScalar(u8, raw_content[0..new_size], '\n');
    while(iter.next()) |cmd| {
        if (cmd.len == 0) continue;
        //the key is the first KEY_SIZE bytes of cmd that are not spaces
        var key_buf: [KEY_SIZE]u8 = undefined;
        var key_len: usize = 0;
        for (0..key_buf.len) |i| {
            if (i == cmd.len) break;
            if (cmd[i] != ' '){ 
                key_buf[key_len] = cmd[i];
                key_len+=1;
            }
        }
        if (key_len == 0) continue;
        assert(key_len <= KEY_SIZE);
        const key = try self.arena.dupe(u8, key_buf[0..key_len]);
        if (self.map.get(key)) |node| {
               node.data.reruns += 1; 
               self.list.remove(node);
               self.list.append(node);
        } else {
            const cmd_trimmed = try self.arena.dupe(u8, std.mem.trim(u8, cmd, " "));
            const new_node = try self.arena.create(List.Node);
            new_node.data = Command{.cmd = cmd_trimmed};
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
const Allocator = std.mem.Allocator;
const ascii = @import("ascii.zig");
