const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;

list_view: vxfw.ListView,
text_field: vxfw.TextField,

pub fn widget(self: *Self) vxfw.Widget {
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
