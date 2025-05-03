const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");

text_field: vxfw.TextField,
text: vxfw.Text,
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
        .init => {
            try self.text_field.insertSliceAtCursor("> ");
        },
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

    const text_len: u16 = @intCast(self.text.text.len);
    const text: vxfw.SubSurface = .{
        .origin = .{ .row = 1, .col = (max.width / 2) - 8},
        .surface = try self.text.draw(ctx.withConstraints(ctx.min, .{ .width = text_len, .height = 1})),
    };

    const text_field: vxfw.SubSurface = .{
        .origin = .{ .row = max.height - 2, .col = 2},
        .surface = try self.text_field.draw(ctx.withConstraints(
            ctx.min, .{ .width = 100, .height = 1},
        )),
    };

    const children = try ctx.arena.alloc(vxfw.SubSurface, 2);
    children[0] = text_field;
    children[1] = text;
    return .{
        .size = max,
        .widget = self.widget(),
        .buffer = &.{},
        .children = children, 
    };
}

//THIS TWO FUNCTIONS SHOULD NOT BE HERE, THEY BELONG TO PROMPT / TEXT_FIELD

pub fn onChange(_: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
        // const ptr = maybe_ptr orelse return;
        // const self: *Self = @ptrCast(@alignCast(ptr));
        // try self.text_fieldcinsertSliceAtCursor("You typed something!");
        return;
}


pub fn onSubmit(maybe_ptr: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
    const ptr = maybe_ptr orelse return;
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.text_field.deleteAfterCursor();
    self.text_field.deleteBeforeCursor();
    try self.text_field.insertSliceAtCursor("> ");
    return;
}
