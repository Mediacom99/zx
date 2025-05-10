text_field: vxfw.TextField,
list_view: vxfw.ListView,
text: vxfw.Text,
history: History,
list_items: std.ArrayList(vxfw.RichText),
arena: std.heap.ArenaAllocator,

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
            //Allocate enough RichText for all items in list
            const allocator = self.arena.allocator();
            var temp = self.history.list.last;
            log.debug("Commands: {d}", .{self.history.list.len});
            while (temp) |node| {
                var spans = std.ArrayList(vxfw.RichText.TextSpan).init(allocator);
                try spans.append(.{.text = node.data.cmd, .style = .{.bold = true}});
                try self.list_items.append(.{.text = spans.items, .text_align = .left});
                temp = node.prev;
            }
            try self.text_field.insertSliceAtCursor("> ");
            return ctx.requestFocus(self.text_field.widget());
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

    const text: vxfw.SubSurface = .{
        .origin = .{ .row = 1, .col = 0},
        .surface = try self.text.draw(ctx.withConstraints(ctx.min, .{ .width = max.width, .height = 1})),
    };

    const text_field: vxfw.SubSurface = .{
        .origin = .{ .row = max.height - 2, .col = 2},
        .surface = try self.text_field.draw(ctx.withConstraints(
            ctx.min, .{ .width = 100, .height = 1},
        )),
    };

    const list_view: vxfw.SubSurface = .{
        .origin = .{ .row = 5, .col = 2 }, 
        .surface = try self.list_view.draw(ctx.withConstraints(
            ctx.min, .{ .width = 100, .height = max.height - 10},
        )),
    };

    const children = try ctx.arena.alloc(vxfw.SubSurface, 3);
    children[0] = text_field;
    children[1] = text;
    children[2] = list_view;
    return .{
        .size = max,
        .widget = self.widget(),
        .buffer = &.{},
        .children = children, 
    };
}

//THIS TWO FUNCTIONS SHOULD NOT BE HERE, THEY BELONG TO PROMPT / TEXT_FIELD
pub fn textFieldOnChange(_: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
        // const ptr = maybe_ptr orelse return;
        // const self: *Self = @ptrCast(@alignCast(ptr));
        // try self.text_fieldcinsertSliceAtCursor("You typed something!");
        return;
}
pub fn textFieldOnSubmit(maybe_ptr: ?*anyopaque, _: *vxfw.EventContext, _: []const u8) anyerror!void {
    const ptr = maybe_ptr orelse return;
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.text_field.deleteAfterCursor();
    self.text_field.deleteBeforeCursor();
    try self.text_field.insertSliceAtCursor("> ");
    return;
}

// Used to build the widget used as list item in ListView
// This is only used in relation to ListView
pub fn listViewWidgetBuilder(ptr: *const anyopaque, idx: usize, _: usize) ?vxfw.Widget {
    const self: *const Self = @ptrCast(@alignCast(ptr));
    if (idx >= self.history.list.len) return null;
    return self.list_items.items[idx].widget();
}

const std = @import("std");
const log = std.log;
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");
