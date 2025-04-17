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
        
        ///TODO Do we need this ?
        alloc: std.mem.Allocator,

        ///Internal arena allocator to manage nodes
        ///Not good if node deallocation is frequent. 
        node_alloc: std.heap.ArenaAllocator, 
        
        /// Current head of linked list (most recent inserted)
        head: ?*Node = undefined,
        
        /// Current tail of linked list (oldest inserted)
        tail: ?*Node = undefined,

        /// Current number of element in linked list
        /// HashMap.Size is u32, dont know if we should match the type of DLL size
        size: HashMap.Size = undefined,
        
        /// Instance of array hash map with Node as value 
        map: HashMap = undefined,

        /// Node of linked list, this object will be the value in the hash map
        //TODO should not be pub 
        pub const Node = struct {
            /// This memory is owned by user, it has to be freed manually.
            value: V = undefined, 
            /// This memory is owned by user, it has to be freed manually.
            key: K = undefined,
            ///Number of times node with same key added
            count: usize = 1,
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

        /// Puts (K,V) in hash map and appends new node to end of linked list.
        /// If entry with same key is already present it will increment that node
        /// counts field and set it as tail.
        pub fn appendUniqueWithArena(self: *Self, key: K, value: V) !void {
            if (@sizeOf(K) == 0 or @sizeOf(V) == 0) {
                @compileError("K or V sizes are zero");
            }
            if (self.map.contains(key)) {
                //increment duplicate field 
                //move to top of list
                //no need to allocate
                @panic("TO_IMPLEMENT");
            }
            var node = try self.node_alloc.allocator().create(Self.Node);
            node.key = key;
            node.value = value;
            node.count = 1;
            
            try self.map.putNoClobber(self.alloc, key, node);

            if (self.size == 0) {
                node.next = null;
                node.prev = null;
                self.head = node;
                self.tail = node;
            } else {
                //Current tail next now points to new node
                self.tail.?.next = node;
                //New node prev now points to current tail
                node.prev = self.tail;
                //New node next points to null
                node.next = null;
                //Tail is new node
                self.tail = node;
            }
            self.size += 1;
            return;
        }
        
        /// walks from tail to head and prints position,K,V for each node
        pub fn debugListFromHead(self: *Self) void {
            std.debug.print("Walking linked list from tail to head...\n", .{});
            var count: usize = 0;
            var current = self.head; 
            while(current) |node| : (current = node.next){
                std.debug.print("[{}] K: {s}; V: {s}\n", .{
                    node.count, node.key, node.value,
                });
                count+=1;
            }
        }
        
        /// Prints all (K,V) pairs in hash map
        pub fn debugHashMap(self: *Self) void {
            std.debug.print("Debug printing hash map pairs...\n", .{});
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
    
    try lh.appendUniqueWithArena("CHIAVEUNO", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVEQUATTRO", "adkasdldadlad");
   
    std.debug.print("LinkedHash size: {}\n", .{lh.size});
    lh.debugListFromHead();
    lh.debugHashMap();
}
