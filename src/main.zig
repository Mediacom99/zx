const std = @import("std");
const History = @import("History.zig");

const historyFilePath = "/home/mediacom/.histfile";
// const historyFilePath = "/home/mediacom/code/zhist/histfile";

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

    history.debugPrint();
}
