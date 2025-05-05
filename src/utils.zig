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
pub fn sanitizeAscii(input: []u8) usize {
    var src_idx: usize = 0;
    var dest_idx: usize = 0;
    while (src_idx < input.len): (src_idx += 1) {
        if (!shouldRemove(input[src_idx])) {
            input[dest_idx] = input[src_idx];
            dest_idx+=1;
        }
    }
    return dest_idx;
}
