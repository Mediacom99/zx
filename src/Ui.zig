text_field: vxfw.TextField,
list_view: vxfw.ListView,
text: vxfw.Text,
history: History,
filtered: std.ArrayList(vxfw.RichText), //FIXME dont need arraylist
allocator: std.mem.Allocator,
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
            // Initialize the filtered list
            const allocator = self.arena.allocator();
            var temp = self.history.store.tail;
            while (temp) |node| {
                var spans = try allocator.alloc(vxfw.RichText.TextSpan, 1);
                spans[0] = .{ .text = node.value };
                const rich_text: vxfw.RichText =.{ .text = spans, .text_align = .left };
                try self.filtered.append(rich_text);
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
    if (idx >= self.filtered.items.len) return null;
    return self.filtered.items[idx].widget();
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

const LinkedHash = @import("LinkedHash.zig");
const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");

