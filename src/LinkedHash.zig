//! Implementation of the combination between an hash map and a doubly linked list.
//! For now only the value is a generic type, the key has to be a []const u8 and use zig default
//! string context.
//! V memory has to be freed by user, we just handle pointers.
const std = @import("std");
const strCtx = std.hash_map.StringContext;

pub fn LinkedHash(comptime V: type) type {
    return struct {
        const Self = @This();
        const HashMap = std.HashMapUnmanaged([]const u8, *Node, strCtx, 80);

        alloc: std.mem.Allocator,

        ///Internal arena allocator to manage nodes
        ///Not good if node deallocation is frequent. 
        node_alloc: std.heap.ArenaAllocator, 
        
        /// Current head of linked list (most recent inserted)
        head: ?*Node = undefined,
        
        /// Current tail of linked list (oldest inserted)
        tail: ?*Node = undefined,

        /// Current number of element in linked list
        size: usize = undefined,
        
        /// Instance of array hash map with Node as value 
        map: HashMap = undefined,

        /// Node of linked list, this object will be the value in the hash map
        //TODO should not be pub 
        pub const Node = struct {
            /// This memory is owned by user, it has to be freed manually.
            value: V = undefined, 
            
            /// next node
            next: ?*Node = null,

            /// previous node
            prev: ?*Node = null,
        };

        pub fn init(alloc: std.mem.Allocator) Self {
            return  .{
                .alloc = alloc,
                .node_alloc = std.heap.ArenaAllocator.init(alloc),
                .head = null,
                .tail = null,
                .size = 0,
                .map = HashMap.empty,
            };
        }
        
        /// Deinit LinkedHash, keys and values need to be freed by caller
        pub fn deinit(self: *Self) void {
            //free all nodes
            self.node_alloc.deinit();
            self.map.deinit(self.alloc);
            self.head = undefined;
            self.tail = undefined;
            self.size = undefined;
            self.* = undefined;
        }
    };
}

test "linked_hash_init" {
    var lh = LinkedHash([]u8).init(std.testing.allocator);
    defer lh.deinit();
    try (std.testing.expect(lh.size == 0));
    try (std.testing.expect(lh.head == null));
    try (std.testing.expect(lh.tail == null));
    try (std.testing.expect(lh.map.size == 0));
    try (std.testing.expect(lh.map.capacity() == 0));
    
    //Alloc a value
    const value = try lh.alloc.alloc(u8, 1);
    defer lh.alloc.free(value);
    @memset(value, 'A');
    
    //Alloc a node
    var nd = try lh.node_alloc.allocator().create(LinkedHash([]u8).Node);
    nd.value = value;
   
    //Try to put and get the node
    try lh.map.put(lh.alloc,"KEY", nd);
    if(lh.map.get("KEY")) |val| {
        try(std.testing.expect(val.value[0] == 'A'));
    } else {
       return error.CANNOT_GET_FROM_HASH; 
    }
}
