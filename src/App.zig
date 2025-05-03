const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");

// list_view: vxfw.ListView = undefined,
text_field: vxfw.TextField = undefined,
history: History,

pub fn widget(self: *Self) vxfw.Widget {
    return .{
        .userdata = self,
        .eventHandler = Self.typeErasedEventHandler,
        .drawFn = Self.typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext,
event: vxfw.Event) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    switch(event) {
        .init => {},
        .key_press => |key| {
            if (key.matches('c', .{ .ctrl = true })) {
                ctx.quit = true;
                return;
            }
            //We handle the event somewhere else, we need only event and ctx
        },
        .focus_in => {
            return ctx.requestFocus(self.text_field.widget());
        },
        else => {},
    }
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const self: *Self = @ptrCast(@alignCast(ptr));
    const max = ctx.max.size();

    const text_field: vxfw.SubSurface = .{
        .origin = .{ .row = max.height - 2, .col = 2},
        .surface = try self.text_field.draw(ctx.withConstraints(
            ctx.min, .{ .width = 100, .height = 100},
        )),
    };

    const children = try ctx.arena.alloc(vxfw.SubSurface, 1);
    children[0] = text_field;
    return .{
        .size = max,
        .widget = self.widget(),
        .buffer = &.{},
        .children = children, 
    };
}
//
//
pub fn onChange(_: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
     return error.TO_IMPLEMENT;
}


pub fn onSubmit(_: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
    return error.TO_IMPLEMENT;
}
