const std = @import("std");
const Service = @import("App.zig");
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
    // var arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const service = try allocator.create(Service);
    defer allocator.destroy(service);

    service.history = try History.init(allocator, hist_file_path);
    defer service.history.deinit();

    service.text_field = .{
        .buf = vxfw.TextField.Buffer.init(allocator),
        .unicode = &app.vx.unicode,
        .userdata = service, 
        .onChange = Service.onChange,
        .onSubmit = Service.onSubmit,
    };
    defer service.text_field.deinit();

    try app.run(service.widget(), .{});
    app.deinit();
}

