pub fn main() !void {
    var hist_file_path: []const u8 = "/home/mediacom/.histfile";
    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |arg| {
       hist_file_path = arg; 
    } else {
        log.info("No file path provided, using default: {s}", .{hist_file_path});
    }
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var history = History.init(allocator, arena);
    defer history.deinit();
    try history.parseFile(hist_file_path);

    const ui = try allocator.create(Ui);
    defer allocator.destroy(ui);

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const Color = vaxis.Cell.Color;
    const gruber_yellow: Color = .{ .rgb =  [_]u8{255, 221, 51} };
    ui.history = history;
    ui.arena = arena;
    ui.list_items = std.ArrayList(vxfw.RichText).init(allocator);
    ui.result = null;
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

    try app.run(ui.widget(), .{.framerate = 60});
    app.deinit();

    if (ui.result) |res| {
        var skip_reruns: usize = 0;
        for (0..res.len) |i| {
            if (res[i] == ']') {
                skip_reruns = i;
                break;
            }
        }
        const prompt = res[skip_reruns + 2..];  // Extracted command string
        try std.io.getStdOut().writer().print("{s}\n", .{prompt});
    }
}

pub fn asTextUpper(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .err => "ERROR",
        .warn => "WARN",
        .info => "INFO",
        .debug => "DEBUG",
    };
}

pub const std_options: std.Options = .{
    .log_level = std.log.default_level,
    .logFn = myLogFn,
};

pub fn myLogFn(
 comptime level: std.log.Level,
 comptime _: @Type(.enum_literal),
 comptime format: []const u8,
 args: anytype,
) void {
 std.debug.lockStdErr();
 defer std.debug.unlockStdErr();
 const stderr = std.io.getStdErr().writer();
 nosuspend stderr.print(asTextUpper(level) ++ ": " ++ format ++ "\n", args) catch return;
}


const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const log = std.log;
