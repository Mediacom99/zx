const std = @import("std");
const History = @import("History.zig");

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

    // var history = History.init(allocator, "/home/mediacom/.bash_history");
    var history = History.init(allocator, "/home/mediacom/development/zhist/prova.txt");
    // var history = History.init(allocator, "/home/mediacom/development/zhist/shakespeare.txt");
    defer {
        history.deinit() catch {
            std.log.err("Error", .{});
        };
    }

    try history.loadAndParseHistoryFile();
    var it = history.hist.iterator();
    while (it.next()) |e| {
        std.debug.print("Cmd: {s}\n", .{e.value_ptr.command});
        std.debug.print("Time: {s}\n", .{e.value_ptr.timestamp});
        std.debug.print("Copies: {d}\n", .{e.value_ptr.copies});
        std.debug.print("\n", .{});
    }
    const end = try std.time.Instant.now();
    const elapsed: f32 = @floatFromInt(end.since(start));
    std.debug.print("Time elapsed: {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
}
