const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const customLogger = @import("log.zig").customLogger;
const log = std.log;
pub const std_options: std.Options = .{
    .log_level = std.log.default_level,
    .logFn = customLogger,
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var from_env: bool = false;

    var args = std.process.args();
    var hist_filepath: []const u8 = undefined;
    _ = args.skip();
    if (args.next()) |arg| {
        hist_filepath = arg;
    } else {
        log.info("No file path provided, looking for .histfile in `HOME` folder", .{});
        const home = std.process.getEnvVarOwned(allocator, "HOME") catch |e| {
            if (e == error.EnvironmentVariableNotFound) {
                log.err("environment variable `HOME` not found", .{});
            }
            return e;
        };
        defer allocator.free(home);
        hist_filepath = try std.fmt.allocPrint(allocator, "{s}/.histfile", .{home});
        from_env = true;
        log.debug("Histfile path found: {s}", .{hist_filepath});
    }
    defer {
        if (from_env) allocator.free(hist_filepath);
    }

    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var history = History.init(allocator, arena);
    defer history.deinit();
    try history.parseFile(hist_filepath);

    const ui = try allocator.create(Ui);
    defer allocator.destroy(ui);

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const Color = vaxis.Cell.Color;
    const gruber_yellow: Color = .{ .rgb = [_]u8{ 255, 221, 51 } };
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

    try app.run(ui.widget(), .{ .framerate = 60 });
    app.deinit();

    if (ui.result) |res| {
        var skip_reruns: usize = 0;
        for (0..res.len) |i| {
            if (res[i] == ']') {
                skip_reruns = i;
                break;
            }
        }
        const prompt = res[(skip_reruns + 2)..]; // Extracted command string
        try std.io.getStdOut().writer().print("{s}\n", .{prompt});
    }
}
