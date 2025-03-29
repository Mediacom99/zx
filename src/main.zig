const std = @import("std");
const HistoryService = @import("HistoryService.zig");
const Ctrl = @import("Controller.zig");

pub fn main() !void {
    const ctrl = Ctrl.init();
    ctrl.printMsg();
    try ctrl.doSmth();
    return;
}
