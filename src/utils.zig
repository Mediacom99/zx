//! Some useful functions

const std = @import("std");

const START_ASCII = 0x1F;
const END_ASCII = 0x7F;

inline fn isNonPrintableAscii(item: u8) bool {
    return item <= START_ASCII;
}

inline fn isExtendedAscii(item: u8) bool {
    return item >= END_ASCII;
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
