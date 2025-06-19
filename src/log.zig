const std = @import("std");

// I can just make this into a type that has its own internal state
// and I can do many nice things. And in the code I just use the standard
// library log functions. Pretty cool.

fn toUppercase(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .err => "ERROR",
        .warn => "WARN",
        .info => "INFO",
        .debug => "DEBUG",
    };
}

pub fn customLogger(
    comptime level: std.log.Level,
    comptime _: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(toUppercase(level) ++ ": " ++ format ++ "\n", args) catch return;
}
