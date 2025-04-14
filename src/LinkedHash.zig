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

        /// puts (K,V) in hash map and appends new node to end of linked list
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
        
        /// walks from tail to head and prints position,K,V for each node
        pub fn debugListFromHead(self: *Self) void {
            var count: usize = 0;
            var current = self.head; 
            while(current) |node| : (current = node.next){
                std.debug.print("[{}] K: {s}; V: {s}\n", .{
                    count, node.key, node.value
                });
                count+=1;
            }
            std.debug.print("DLL size: {}\n", .{self.size});
        }
        
        pub fn debugHashMap(self: *Self) void {
            var iterator = self.map.iterator();
            while (iterator.next()) |kv| {
                std.debug.print("K: {s}; V: {s}\n", .{
                    kv.key_ptr.*, kv.value_ptr.*.value,
                });
            }
        }

        /// deinits LinkedHash, keys and values need to be freed by caller
        pub fn deinit(self: *Self) void {
            //free all nodes
            self.node_alloc.deinit();
            //deinit map
            self.map.deinit(self.alloc);
            self.head = undefined;
            self.tail = undefined;
            self.size = undefined;
            self.* = undefined;
        }
    };
}

test "linked_hash_init" {
    const StringCtx = std.hash_map.StringContext;
    const String = []const u8;
    const CLinkedHash = LinkedHash(String, String, StringCtx);

    var lh = CLinkedHash.init(std.testing.allocator);
    defer lh.deinit();
    
    try lh.append("CHIAVEUNO", "asjkdajsdkasjdkasdjaskdjaskdjaskdjask");
    try lh.append("CHIAVEDUE", "asdjaksdjaskdjaskdjaskdasjdkasjdkasjdkas");
    try lh.append("CHIAVETRE", "adkuik akskudei askdue *((((()))))");
    try lh.append("CHIAVEQUATTRO", "12049-094)(A_)D*(AS&DA(SD)");
    try lh.append("CHIAVECINQUE", "EDOAROASODIASODIASO");
   
    lh.debugListFromHead();
    lh.debugHashMap();
}
