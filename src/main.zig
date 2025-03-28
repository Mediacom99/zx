const std = @import("std");
// Bash writes to history file only when session closes...
pub fn main() !void {
    const bashHistoryPath = "/home/mediacom/.bash_history";
    const file = std.fs.openFileAbsolute(bashHistoryPath, .{}) catch |err| {
        std.log.err("cannot open bash history file: {any}", .{err});
        return err;
    };
    defer file.close();
    var fileBuf: [10 * 1024]u8 = undefined;
    const bytesRead = file.readAll(&fileBuf) catch |err| {
        std.log.err("failed to read file into buffer: {any}", .{err});
        return err;
    };
    std.log.info("bytes read: {d}", .{bytesRead});
    const stdout = std.io.getStdOut();
    const cutFileBuf: []u8 = fileBuf[(bytesRead - 101)..(bytesRead - 1)];
    _ = try stdout.write(cutFileBuf);
    _ = try stdout.write("\n");
    return;
}
