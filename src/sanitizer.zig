//! Sanitize input from history file

const std = @import("std");

/// Sanitizes user input following these steps:
/// 1. control char removal
/// 2. special char escaping
/// 3. command substitution neutralization
/// 4. whitespace normalization
/// 5. input validation (allow only alphanumunicode)
/// 6. encoding validation (?)
pub fn sanitize(_: []u8) !void {
    return error.NotImplemented;
}
