const std = @import("std");
const App = @import("App.zig");

const historyFilePath = "/Users/edoardo/.zsh_history";
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

    var app = try App.init(allocator, historyFilePath);
    defer app.deinit();

    _ = app.prova();

}
