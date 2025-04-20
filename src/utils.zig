//! Bunch of utility functions

const std = @import("std");

inline fn isNonPrintableAscii(item: u8) bool {
    return item <= 0x1f;
}

inline fn isExtendedAscii(item: u8) bool {
    return item >= 0x7f;
}

inline fn shouldRemove(item: u8) bool {
    return (isNonPrintableAscii(item) and item != '\n') or isExtendedAscii(item);
}

//TODO escape control/special chars ($, ...)
pub fn sanitizeAscii(input: []u8) void {
    var src: usize = 0;
    var dst: usize = 0;
    while (src < input.len): (src += 1) {
        if (!shouldRemove(input[src])) {
            input[dst] = input[src];
            dst+=1;
        }
    }
    return;
}
