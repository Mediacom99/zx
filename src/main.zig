const std = @import("std");
const Ui = @import("Ui.zig");
const History = @import("History.zig");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const hist_file_path = args.next() orelse {
         return History.HistoryError.InvalidFilePath;
    };
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // var arena = std.heap.ArenaAllocator.init(allocator);
    // defer arena.deinit();

    var history = try History.init(allocator, hist_file_path);
    defer history.deinit();

    history.store.printListFromHead();

    // var app = try vxfw.App.init(allocator);
    // const ui = try allocator.create(Ui);
    // defer allocator.destroy(ui);


   //  const Color = vaxis.Cell.Color;
   //  const gruber_yellow: Color = .{ .rgb =  [_]u8{255, 221, 51} };
   //  ui.allocator = allocator;
   //  ui.arena = std.heap.ArenaAllocator.init(allocator); //FIXME
   //  ui.filtered = std.ArrayList(vxfw.RichText).init(allocator);
   //  ui.text = .{
   //      .text = "Welcome to Zhist!",
   //      .width_basis = .parent,
   //      .text_align = .center,
   //      .style = .{ .fg = gruber_yellow },
   //  };
   //  ui.text_field = .{
   //      .buf = vxfw.TextField.Buffer.init(allocator),
   //      .unicode = &app.vx.unicode,
   //      .userdata = ui, 
   //      .onChange = Ui.textFieldOnChange,
   //      .onSubmit = Ui.textFieldOnSubmit,
   //  };
   // ui.list_view = .{
   //      .children = .{ 
   //          .builder = .{
   //              .userdata = ui,
   //              .buildFn = Ui.listViewWidgetBuilder,
   //          },   
   //      },
   //  };
   //  defer ui.text_field.deinit();
   //  defer ui.filtered.deinit();
   //  defer ui.arena.deinit();
   //
   //  try app.run(ui.widget(), .{});
   //  defer app.deinit();
}

