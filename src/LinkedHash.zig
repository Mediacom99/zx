//! LinkedHash is the combination between a doubly linked list and a hash map. Every node 
//! in the doubly linked list is also hashed for O(1) retrieval.
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
        node_alloc: *std.heap.ArenaAllocator, 
        
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

        pub fn init(alloc: std.mem.Allocator, arena: *std.heap.ArenaAllocator) Self {
            return  .{
                .alloc = alloc,
                .node_alloc = arena,
                .map = HashMap.empty,
                .head = null,
                .tail = null,
                .size = 0,
            };
        }

        /// deinits LinkedHash, keys and values need to be freed by caller
        pub fn deinit(self: *Self) void {
            //deinit map
            self.map.deinit(self.alloc);
            self.head = undefined;
            self.tail = undefined;
            self.size = undefined;
            self.* = undefined;
        }


        /// walks from tail to head and prints position,K,V for each node
        pub fn printListFromHead(self: *Self) void {
            var count: usize = 0;
            var current = self.head; 
            while(current) |node| : (current = node.next){
               log.info("[{}] {{ {s} }} {{ {s} }}", .{
                    node.count, node.key, node.value,
                });
                count+=1;
            }
        }
        
        /// Prints all (K,V) pairs in hash map
        pub fn printHashMap(self: *Self) void {
            var iterator = self.map.iterator();
            while (iterator.next()) |kv| {
                log.info("[ {s}, {s} ]", .{
                    kv.key_ptr.*, kv.value_ptr.*.value,
                });
            }
        }

        /// Puts (K,V) in hash map and appends new node to end of linked list.
        /// If entry with same key is already present it will increment that node's
        /// count field and move it to end of list.
        pub fn appendUniqueWithArena(self: *Self, key: K, value: V) !void {
            if (@sizeOf(K) == 0 or @sizeOf(V) == 0) {
                @compileError("K or V sizes are zero");
            }
            if (self.map.contains(key)) {
                // log.debug("Duplicate key found!", .{});
                const dupe_node = self.map.get(key).?;
                dupe_node.count+=1;
                self.moveToEnd(dupe_node);
                return;
            }
            //New node
            var node = try self.node_alloc.allocator().create(Self.Node);
            node.key = key;
            node.value = value;
            node.count = 1;
            try self.map.putNoClobber(self.alloc, node.key, node);
            self.append(node);
            self.size += 1;
            return;
        }
        
        ///Appends node to end of linked list, does not increase list size.
        fn append(self: *Self, node: *Node) void {
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
            return;
        }

        ///Moves current node to end of linked list
        fn moveToEnd(self: *Self, val: *Node) void {
            if(val == self.tail) {
                return; 
            }
            if (val == self.head) {
                //quello dopo diventa head 
                val.next.?.prev = null;
                self.head = val.next;
                //We move val to end
                val.prev = self.tail;
                self.tail.?.next = val;
                val.next = null;
                //set tail to val
                self.tail = val;
                return;
            }
            //Attacca quelli a dx e sx di val
            val.prev.?.next = val.next;
            val.next.?.prev = val.prev;

            //attaco al current tail
            self.tail.?.next = val;
            val.prev = self.tail;
            val.next = null;

            //setto tail a val
            self.tail = val;
            return;
        }
        
    };
}

test "linked_hash_init" {
    const StringCtx = std.hash_map.StringContext;
    const String = []const u8;
    const CLinkedHash = LinkedHash(String, String, StringCtx);

    std.testing.log_level = std.log.Level.info;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var lh = CLinkedHash.init(std.testing.allocator, &arena);
    defer lh.deinit();
    
    try lh.appendUniqueWithArena("CHIAVEQUATTRO", "adkasdldadlad");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVEDUE", "qualcosa anche da mettere qui");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVEQUATTRO", "adkasdldadlad");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("ciao", "valore numero uno");
    try lh.appendUniqueWithArena("CHIAVETRE", "dai anche qua forse bozzolante");
    try lh.appendUniqueWithArena("CHIAVEQUATTRO", "adkasdldadlad");
   
    log.info("LinkedHash size: {}", .{lh.size});
    lh.printListFromHead();
    lh.printHashMap();
}
