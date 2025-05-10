pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const hist_file_path = args.next() orelse {
         return History.Error.MissingFilePath;
    };

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var history = History.init(allocator, hist_file_path);
    defer history.deinit();
    try history.parseFile(hist_file_path);

    const ui = try allocator.create(Ui);
    defer allocator.destroy(ui);

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const Color = vaxis.Cell.Color;
    const gruber_yellow: Color = .{ .rgb =  [_]u8{255, 221, 51} };
    ui.history = history;
    ui.arena = std.heap.ArenaAllocator.init(allocator);
    ui.list_items = std.ArrayList(vxfw.RichText).init(allocator);
    ui.selected = std.ArrayList([]const u8).init(allocator);
    ui.text = .{
        .text = "Welcome to Zhist!",
        .width_basis = .parent,
        .text_align = .center,
        .style = .{ .fg = gruber_yellow },
    };
    ui.text_field = .{
        .buf = vxfw.TextField.Buffer.init(allocator),
        .unicode = &app.vx.unicode,
        .userdata = ui, 
        .onChange = Ui.textFieldOnChange,
        .onSubmit = Ui.textFieldOnSubmit,
    };
    ui.list_view = .{
        .children = .{ 
            .builder = .{
                .userdata = ui,
                .buildFn = Ui.listViewWidgetBuilder,
            },   
        },
    };
    defer ui.text_field.deinit();
    defer ui.arena.deinit();
    defer ui.list_items.deinit();
    defer ui.selected.deinit();

    try app.run(ui.widget(), .{.framerate = 60});
    app.deinit();

    const writer = std.io.getStdOut().writer();
    for (ui.selected.items) |txt| {
        try writer.print("{s}\n", .{txt});
    }
}


const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const log = std.log;
