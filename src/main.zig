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
        const home =
            std.process.getEnvVarOwned(allocator, "HOME") catch |e| {
                if (e == error.EnvironmentVariableNotFound) {
                    log.err("environment variable `HOME` not found", .{});
                }
                return e;
            };
        defer allocator.free(home);
        from_env = true;
        hist_filepath = try std.fmt.allocPrint(allocator, "{s}/.histfile", .{home});
        log.debug("Histfile path found: {s}", .{hist_filepath});
    }
    defer {
        if (from_env) allocator.free(hist_filepath);
    }

    var history = History.init(allocator);
    defer history.deinit();

    try history.parseFile(hist_filepath);

    var app = try vxfw.App.init(allocator);
    errdefer app.deinit();

    const ui = try Ui.init(allocator, &app, history);
    defer ui.deinit();

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
        // Extracted command string
        const output = res[(skip_reruns + 2)..];
        try std.io.getStdOut().writer().print("{s}", .{output});
    }
}
