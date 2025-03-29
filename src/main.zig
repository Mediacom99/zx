const std = @import("std");
const History = @import("History.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var history = History.init(allocator, "/home/mediacom/.bash_history");
    // var history = History.init(allocator, "/home/mediacom/development/zhist/prova");
    defer history.deinit();

    return history.loadAndParseHistoryFile();
}
