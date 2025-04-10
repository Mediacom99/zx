const std = @import("std");
const App = @import("App.zig");


pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const historyFilePath = args.next() orelse {
         return error.InvalidHistoryFilePath;
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != std.heap.Check.ok) {
            std.log.err("Memory leak detected!\n", .{});
        }
    }

    const allocator = gpa.allocator();
    var app = try App.init(allocator, historyFilePath);
    defer app.deinit();
    app.history.debugPrint();
}
