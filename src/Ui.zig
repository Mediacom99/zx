const std = @import("std");
const log = std.log;
const assert = std.debug.assert;
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;
const Self = @This();
const Allocator = std.mem.Allocator;
const History = @import("History.zig");

text_field: vxfw.TextField,
list_view: vxfw.ListView,
text: vxfw.Text,
history: History,
list_items: std.ArrayList(vxfw.RichText),
arena: Allocator,
result: ?[]const u8,

pub fn widget(self: *Self) vxfw.Widget {
    return .{
        .userdata = self,
        .eventHandler = Self.typeErasedEventHandler,
        .drawFn = Self.typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
    const self: *Self = @ptrCast(@alignCast(ptr));
    switch (event) {
        .init => {
            //Text field
            try self.text_field.insertSliceAtCursor("> ");

            //List view
            var temp = self.history.list.last;
            log.debug("Commands: {d}", .{self.history.list.len});
            while (temp) |node| {
                var spans = std.ArrayList(vxfw.RichText.TextSpan).init(self.arena);
                const text = try std.fmt.allocPrint(self.arena, "[{d}] {s}", .{ node.data.reruns, node.data.cmd });
                const text_span: vxfw.RichText.TextSpan = .{ .text = text, .style = .{ .bold = false } };
                try spans.append(text_span);
                const rich_text: vxfw.RichText = .{ .text = spans.items, .text_align = .left };
                try self.list_items.append(rich_text);
                temp = node.prev;
            }

            return ctx.requestFocus(self.list_view.widget());
        },
        .key_press => |key| {
            if (key.matches('q', .{})) {
                ctx.quit = true;
                return;
            }
            if (key.matches('/', .{})) {
                return ctx.requestFocus(self.text_field.widget());
            }
            if (key.matches(vaxis.Key.enter, .{})) {
                const rt = self.list_items.items[self.list_view.cursor];
                assert(rt.text.len == 1);
                self.result = rt.text[0].text;
                ctx.quit = true;
            }
            return self.list_view.handleEvent(ctx, event);
        },
        .focus_in => {
            return ctx.requestFocus(self.list_view.widget());
        },
        else => {},
    }
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) Allocator.Error!vxfw.Surface {
    const self: *Self = @ptrCast(@alignCast(ptr));
    const max = ctx.max.size();
    const text: vxfw.SubSurface = .{
        .origin = .{ .row = 1, .col = 0 },
        .surface = try self.text.draw(ctx.withConstraints(ctx.min, .{ .width = max.width, .height = 1 })),
    };
    const text_field: vxfw.SubSurface = .{
        .origin = .{ .row = max.height - 2, .col = 2 },
        .surface = try self.text_field.draw(ctx.withConstraints(
            ctx.min,
            .{ .width = 100, .height = 1 },
        )),
    };
    const list_view: vxfw.SubSurface = .{
        .origin = .{ .row = 3, .col = 2 },
        .surface = try self.list_view.draw(ctx.withConstraints(
            ctx.min,
            .{ .width = ctx.max.width, .height = max.height - 6 },
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
pub fn textFieldOnSubmit(maybe_ptr: ?*anyopaque, event_ctx: *vxfw.EventContext, _: []const u8) anyerror!void {
    const ptr = maybe_ptr orelse return;
    const self: *Self = @ptrCast(@alignCast(ptr));
    self.text_field.clearAndFree();
    try self.text_field.insertSliceAtCursor("> ");
    try event_ctx.requestFocus(self.list_view.widget());
    return;
}

// Used to build the widget used as list item in ListView
// This is only used in relation to ListView
pub fn listViewWidgetBuilder(ptr: *const anyopaque, idx: usize, _: usize) ?vxfw.Widget {
    const self: *const Self = @ptrCast(@alignCast(ptr));
    if (idx >= self.history.list.len) return null;
    return self.list_items.items[idx].widget();
}

test {
    std.log.debug("Hello!", .{});
}
