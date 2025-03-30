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

    const start = try std.time.Instant.now();

    var history = History.init(allocator);
    defer history.deinit();

    try history.parseHistoryFile(historyFilePath);

    var it = history.hist.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.copies > 50) {
            std.debug.print("Cmd: {s}\n", .{e.value_ptr.command});
            std.debug.print("Time: {s}\n", .{e.value_ptr.timestamp});
            std.debug.print("Copies: {d}\n", .{e.value_ptr.copies});
            std.debug.print("\n", .{});
        }
    }

    const end = try std.time.Instant.now();
    const elapsed: f32 = @floatFromInt(end.since(start));
    std.log.info("Time elapsed: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
}
