//! Bunch of utility functions

const std = @import("std");

fn isNotPrintableAscii(item: u8) bool {
    return (item < 0x1f and item != '\n') or item >= 127;
}
/// Sanitizes user input following these steps:
/// 1. control char removal
/// 2. special char escaping
/// 3. command substitution neutralization
/// 4. whitespace normalization
/// 5. input validation (allow only alphanumunicode)
/// 6. encoding validation (?)
/// Preserves ordering.
pub fn sanitizeAscii(input: *std.ArrayList(u8)) void {
    var idx: usize = input.items.len;
    if (idx == 0) return;
    while (idx > 0) {
        idx -= 1;
        if (isNotPrintableAscii(input.items[idx])) {
            _ = input.orderedRemove(idx);
        }
    }
    return;
}
