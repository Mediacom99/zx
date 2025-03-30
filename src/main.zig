const std = @import("std");
const History = @import("History.zig");

// const historyFilePath = "/home/mediacom/development/zhist/prova.txt";
const historyFilePath = "/home/mediacom/.bash_history";

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    var history = try History.init(allocator, historyFilePath);
    defer history.deinit();

    var iterator = history.hist.iterator();
    while (iterator.next()) |e| {
        std.log.debug("{s}", .{e.value_ptr.command});
    }
}
