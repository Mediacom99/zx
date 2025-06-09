pub const Slab = struct {
    I16: []i16,
    I32: []i32,

    /// Allocates space given size16 and size32 and returns a new slab with undefined elements.
    /// Caller owns the returned memory.
    pub fn initUnmanaged(alloc: Allocator, size16: usize, size32: usize) !Slab {
        const isxt = try alloc.alloc(i16, size16);
        const itr = try alloc.alloc(i32, size32);
        return Slab{.I16 = isxt, .I32 = itr};
    }
};

const Allocator = std.mem.Allocator;
const std = @import("std");
