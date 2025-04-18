const std = @import("std");
const App = @import("App.zig");
const History = @import("History.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const historyFilePath = args.next() orelse {
         return error.InvalidHistoryFilePath;
    };

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            std.log.err("Memory leak detected!\n", .{});
        }
    }

    const allocator = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var hist = try History.init(allocator, &arena, historyFilePath);
    defer hist.deinit();
    hist.store.printListFromHead();
}
