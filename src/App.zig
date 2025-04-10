const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");

list_view: vxfw.ListView = undefined,
text_field: vxfw.TextField = undefined,
history: History,

pub fn init(allocator: Allocator, historyFilePath: []const u8) !Self {
    return Self {
        .history = try History.init(allocator, historyFilePath),
    };
}

pub fn deinit(self: *Self) void {
    self.history.deinit();
    return;
}

pub fn widget(self: *Self) vxfw.Widget {
    self.history.debugPrint();
    return .{
        .userdata = self,
        .eventHandler = Self.typeErasedEventHandler,
        .drawFn = Self.typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext,
event: vxfw.Event) anyerror!void {
     return error.TO_IMPLEMENT;
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    return error.TO_IMPLEMENT;
}


fn onChange(maybe_ptr: ?*anyopaque, _: *vxfw.EventContext, str: []const u8) anyerror!void {
     return error.TO_IMPLEMENT;
}


fn onSubmit(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext, _: []const u8) anyerror!void {
    return error.TO_IMPLEMENT;
}
