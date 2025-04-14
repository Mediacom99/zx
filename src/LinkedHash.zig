//! Implementation of the combination between an hash map and a doubly linked list.
//! For now only the value is a generic type, the key has to be a []const u8 and use zig default
//! string context.
//! V memory has to be freed by user, we just handle pointers.
//! TODO:
//!     1. Add capacity and ability to preallocate (and all the assumeCapacity functions)
//!     2. Add support for custom contexts (like StringContext in std)
//!     3. Add support for generic keys
//!
//! The structure is: head -> [Node 1, first added] <-> [Node 2] <-> ... <-> [Node N, last added] <- tail

const std = @import("std");
const log = std.log;

pub fn LinkedHash(comptime K: type, comptime V: type, comptime Context: type) type {
    //TODO add check for types K, V and Context
    return struct {
        const Self = @This();
        const HashMap = std.HashMapUnmanaged(K, *Node, Context, 80);
        
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
            /// This memory is owned by user, it has to be freed manually.
            key: K = undefined,
            next: ?*Node = undefined,
            prev: ?*Node = undefined,
        };

        pub fn init(alloc: std.mem.Allocator) Self {
            return  .{
                .alloc = alloc,
                .node_alloc = std.heap.ArenaAllocator.init(alloc),
                .map = HashMap.empty,
                .head = null,
                .tail = null,
                .size = 0,
            };
        }

        ///Append (K,V) to end of linked list (where tail points to)
        pub fn append(self: *Self, key: K, val: V) !void {
            //todo add checking for the types V and K
            var node = try self.node_alloc.allocator().create(Self.Node);
            node.key = key;
            node.value = val;
            node.next = null;
            node.prev = null;
            if (self.size == 0) {
                self.head = node;
                self.tail = node;
            } else {
                //Old last one now points to new node
                self.tail.?.next = node;
                //New node prev now points to last old one
                node.prev = self.tail;
                //Head is now new one
                self.tail = node;
            }
            self.map.put(self.alloc, key, node) catch |err| {
                std.debug.print("Cannot put into map: {}\n",.{err});
            };
            self.size += 1;
            return;
        }
        
        /// Walsk from tail to head and prints K,V for each node
        pub fn debugListFromHead(self: *Self) void {
            var count: usize = 0;
            var current = self.head; 
            while(current) |node| : (current = node.next){
                std.debug.print("[{}] K: {s}; V: {s}\n", .{
                    count, node.key, node.value
                });
                count+=1;
            }
            std.debug.print("DLL size: {}", .{self.size});
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
    const strCtx = std.hash_map.StringContext;
    const CLinkedHash = LinkedHash([]const u8, []const u8, strCtx);
    var lh = CLinkedHash.init(std.testing.allocator);
    defer lh.deinit();
    try (std.testing.expect(lh.size == 0));
    try (std.testing.expect(lh.head == null));
    try (std.testing.expect(lh.tail == null));
    try (std.testing.expect(lh.map.size == 0));
    try (std.testing.expect(lh.map.capacity() == 0));
    
    //Append node
    try lh.append("CHIAVEUNO", "asjkdajsdkasjdkasdjaskdjaskdjaskdjask");
    try lh.append("CHIAVEDUE", "asdjaksdjaskdjaskdjaskdasjdkasjdkasjdkas");
   
    //Try to put and get the node
    lh.debugListFromHead();
}
