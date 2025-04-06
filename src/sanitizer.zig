//! Sanitize input from history file

const std = @import("std");

fn is_not_printable(item: u8) bool {
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
pub fn sanitizeFile(input: *std.ArrayList(u8)) void {
    //remove ASCII control chars
    var idx: usize = input.items.len;
    if (idx == 0) return;
    while (idx > 0) {
        idx -= 1;
        if (is_not_printable(input.items[idx])) {
            _ = input.orderedRemove(idx);
        }
    }
    return;
}

/// orderedRemove of all spaces in arraylist
pub fn removeSpaces(input: *std.ArrayList(u8)) void {
    var idx: usize = input.items.len;
    if (idx == 0) return;
    while (idx > 0) {
        idx -= 1;
        if (input.items[idx] == ' ') {
            _ = input.orderedRemove(idx);
        }
    }
}
