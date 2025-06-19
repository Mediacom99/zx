const unicode = @import("./fuzzy/unicode.zig");
const Map = std.StringHashMap(*List.Node);
const List = std.DoublyLinkedList(Command);
const Self = @This();
const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const log = std.log;
const Allocator = std.mem.Allocator;

pub const Error = error {
    EmptyFile,
    FileTooBig_Max50MB,
};

///max non-space bytes hashed to create the key
const key_size: usize = 256;

const max_file_size: usize = 512 * 1024 * 100; //50MB

pub const Command = struct {
    cmd: []const u8,
    reruns: usize = 1,
};

list: List = undefined,

map: Map = undefined,

gpa: Allocator,

arena: Allocator,

pub fn init(allocator: Allocator, arena: Allocator) Self {
    return .{
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
    if (size > max_file_size) { return Error.FileTooBig_Max50MB; }

    var content: []u8 = undefined;
    if(builtin.target.os.tag == .linux) {
        content = try std.posix.mmap(
            null,
            size, 
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{.TYPE = .PRIVATE},
            file.handle,
            0
        );
        if (content.len == 0) {
            return Error.EmptyFile;
        }
        log.debug("history file loaded, bytes mmapped to vmem: {}", .{content.len});
    } else {
        content = try self.gpa.alloc(u8, size);
        const bytes_read = try file.readAll(content);
        if (bytes_read == 0) {
            return Error.EmptyFile;
        }
        log.debug("history file loaded, bytes read: {d}", .{bytes_read});
    }
    assert(content.len == size);
    
    // I dont like this allocating a whole new slice but its needed
    // to add utf8 replacement char. We could allocate 3 bytes per not ascii char
    // for more memory consumption but faster execution.
    const valid_content = try unicode.sanitizeUtf8UnmanagedStd(self.gpa, content);
    defer self.gpa.free(valid_content);

    if (builtin.target.os.tag == .linux) {
        std.posix.munmap(@alignCast(content));
    } else {
       self.gpa.free(content);
    }

    var iter = std.mem.splitScalar(u8, valid_content, '\n');
    while(iter.next()) |cmd| {
        if (cmd.len == 0) continue;
        //the key is the first KEY_SIZE bytes of cmd that are not spaces
        var key_buf: [key_size]u8 = undefined;
        var key_len: usize = 0;
        for (0..key_buf.len) |i| {
            if (i == cmd.len) break;
            if (cmd[i] != ' '){ 
                key_buf[key_len] = cmd[i];
                key_len+=1;
            }
        }
        if (key_len == 0) continue;
        assert(key_len <= key_size);
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

//TODOs
// Generate a bunch of random binary inputs to test.
// try fuzzy testing ?
// time it
// move time calculation into its own source file in benchmarks folder
test "historyParseFile with big file size" {
    std.testing.log_level = .debug;
    const file_path = "./assets/85374042_p0.png";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var history = Self.init(std.testing.allocator, arena.allocator());
    defer history.deinit();

    const start = std.time.nanoTimestamp(); 
    try history.parseFile(file_path);
    const nano_elapsed: f128 = @floatFromInt(std.time.nanoTimestamp() - start);
    try std.testing.expectEqual(history.list.len, history.map.count());
    std.log.debug("History.parseFile took: {e} seconds", .{nano_elapsed / (std.time.ns_per_s)});
}
