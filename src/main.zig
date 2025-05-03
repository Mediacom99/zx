const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

// pub fn main() !void {
//     var args = std.process.args();
//     _ = args.skip();
//     const historyFilePath = args.next() orelse {
//          return History.HistoryError.InvalidFilePath;
//     };
//
//     var gpa = std.heap.DebugAllocator(.{}).init;
//     defer {
//         const leaked = gpa.deinit();
//         if (leaked != std.heap.Check.ok) {
//             std.log.err("Memory leak detected!\n", .{});
//         }
//     }
//
//     const allocator = gpa.allocator();
//     var hist = try History.init(allocator, historyFilePath);
//     defer hist.deinit();
//     hist.store.printListFromHead();
// }


pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const hist_file_path = args.next() orelse {
         return History.HistoryError.InvalidFilePath;
    };

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const ui = try allocator.create(Ui);
    defer allocator.destroy(ui);

    ui.history = try History.init(allocator, hist_file_path);
    defer ui.history.deinit();

    const Color = vaxis.Cell.Color;
    const gruber_yellow: Color = .{ .rgb =  [_]u8{255, 221, 51} };
    ui.text = .{
        .text = "Welcome to Zhist!",
        .text_align = .center,
        .style = .{ .fg = gruber_yellow },
    };
    ui.text_field = .{
        .buf = vxfw.TextField.Buffer.init(allocator),
        .unicode = &app.vx.unicode,
        .userdata = ui, 
        .onChange = Ui.onChange,
        .onSubmit = Ui.onSubmit,
    };
    defer ui.text_field.deinit();

    try app.run(ui.widget(), .{});
    defer app.deinit();
}

