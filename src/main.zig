const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const hist_file_path = args.next() orelse {
         return History.Error.InvalidFilePath;
    };

    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var history = History.init(allocator, hist_file_path);
    defer history.deinit();
    
    try history.parseFile(hist_file_path);
    // history.debugPrintList();

    const ui = try allocator.create(Ui);
    defer allocator.destroy(ui);

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const Color = vaxis.Cell.Color;
    const gruber_yellow: Color = .{ .rgb =  [_]u8{255, 221, 51} };
    ui.list_items = std.ArrayList(vxfw.RichText).init(allocator);
    ui.history = history;
    ui.arena = arena;
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
    defer ui.list_items.deinit();

    try app.run(ui.widget(), .{});
    app.deinit();
}
