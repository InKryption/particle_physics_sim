const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
    defer _ = gpa.deinit();
    
    var mempool = std.heap.FixedBufferAllocator.init(try gpa.allocator.alloc(u8, 16_384));
    defer gpa.allocator.free(mempool.buffer);
    
    const Coord = struct {
        x: usize   = 0, 
        y: usize   = 0, 
    };
    
    var reg = EntityRegistry.Components{};
    defer reg.deinit(&mempool.allocator);
    
    try reg.addType(&mempool.allocator, Coord, 4);
    
    if (true) return;
    
    const wnd = try sdl.Window.init(.{.w = 1920 / 1.5, .h = 1080 / 1.5});
    defer wnd.deinit();
    
    const rnd = try wnd.createRenderer(.{.presentvsync = true});
    defer rnd.deinit();
    
    var evt = sdl.Event{};
    
    var time_begin: i64 = std.time.milliTimestamp();
    mainloop: while (true) {
        
        while (evt.poll()) |event| switch(event.id) {
            .quit => break :mainloop,
            else => {},
        };
        
        const frame_duration = std.time.milliTimestamp() - time_begin;
        if (std.time.milliTimestamp() - time_begin > 16) {
            time_begin = std.time.milliTimestamp();
        } else std.time.sleep(@intCast(u64, frame_duration) * 1000);
        
        
        
        try rnd.drawColor(sdl.Color.black);
        try rnd.drawClear();
        
        rnd.drawUpdate();
        
    }
}

const EntityRegistry = struct {
    components: Components = .{},
    entities: EntitySet = .{},
    
    
    const EntitySet = struct {
        counter: usize = 0,
        dense: []EntityId = []EntityId{},
        sparse: []*EntityId = []*EntityId{},
        
        pub fn generate(self: *@This(), allocator: *std.mem.Allocator) !EntityId {
            
            self.dense  = try allocator.reallocAdvanced(self.dense , null, self.dense.len + 1, .at_least);
            errdefer allocator.free(new_mem_dense);
            
            self.sparse = try allocator.reallocAdvanced(self.sparse, null, self.counter      , .at_least );
            errdefer allocator.free(new_mem_sparse);
            
            
            
        }
        
        const EntityId = enum(usize) {
            _,
            
            pub fn value(self: EntityId) usize {
                return @enumToInt(self);
            }
            
        };
        
    };
    
    const Components = struct {
        list: std.ArrayListUnmanaged( std.ArrayListUnmanaged(u8) ) = .{},
        
        
        
        const ComponentError = error {
            ComponentDoesntExist,
            ComponentAlreadyExists,
        };
        
        
        
        fn addType(self: *@This(), allocator: *std.mem.Allocator, comptime T: type, init_capacity: usize) !void {
            
            TypeId.generateFor(T) catch {}; // Ensure that id exists.
            const type_id = TypeId.getIdAssume(T); // Assume id exists, since we just made sure it does.
            
            const old_len = self.list.items.len;
            const type_id_value = type_id.value();
            
            if (type_id_value < old_len)
            return ComponentError.ComponentAlreadyExists;
            
            const new_size = std.math.max( old_len , type_id_value + 1 );
            try self.list.resize( allocator, new_size );
            
            const new_memory = try allocator.allocAdvanced(T, null, init_capacity, .at_least);
            
            self.list.items[type_id_value].items.len = 0;
            self.list.items[type_id_value].capacity  = new_memory.len * @sizeOf(T);
            
            self.list.items[type_id_value].items.ptr = @ptrCast([*]u8, new_memory.ptr);
            
        }
        
        fn getType(self: *@This(), comptime T: type) ?std.ArrayListUnmanaged(T) {
            
            const byte_array = self.getBytes(T) orelse return null;
            var out: std.ArrayListUnmanaged(T) = .{};
            
            out.items.ptr = @ptrCast([*]T, @alignCast(@alignOf(T), byte_array.items.ptr));
            out.items.len = byte_array.items.len / @sizeOf(T);
            out.capacity = byte_array.capacity / @sizeOf(T);
            
            return out;
            
        }
        
        
        
        fn updateBytes(self: *@This(), comptime T: type, with: struct { len: usize, capacity: usize }) !void {
            
            const byte_array = self.getBytes(T) orelse return ComponentError.ComponentDoesntExist;
            
            byte_array.items.len = @sizeOf(T) * with.len;
            byte_array.capacity  = @sizeOf(T) * with.capacity;
            
        }
        
        fn getBytes(self: *@This(), comptime T: type) ?*std.ArrayListUnmanaged(u8) {
            
            const type_id = TypeId.of(T) catch return null;
            const type_id_value = type_id.value();
            
            return if (type_id_value >= self.list.items.len)
            null else &self.list.items[type_id_value];
            
        }
        
        
        
        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            
            for (self.list.items) |*comp_list| {
                comp_list.expandToCapacity();
                comp_list.deinit(allocator);
            }
            
            self.list.deinit(allocator);
            
        }
        
        const TypeId = enum(usize) {
            None = 0, /// Default, 'invalid' value for an entity.
            _,
            
            pub fn value(self: TypeId) usize {
                return @enumToInt(self);
            }
            
            /// Get the the type id if it exists.
            pub fn of(comptime T: type) ComponentError!TypeId {
                return if (Static(T).id == .None)
                ComponentError.ComponentDoesntExist else getIdAssume(T);
            }
            
            /// Generates the type id for type T, unless said type already has an associated id, in which case it errors.
            pub fn generateFor(comptime T: type) ComponentError!void {
                
                if (Static(T).id != .None)
                return ComponentError.ComponentAlreadyExists;
                
                counter += 1;
                Static(T).id = @intToEnum(TypeId, counter);
                
            }
            
            /// Returns the type id assuming it already exists. Prefer using 'TypeId.of(T)' which returns an error if the id doesn't exist.
            pub fn getIdAssume(comptime T: type) TypeId {
                return Static(T).id;
            }
            
            fn Static(comptime T: type) type {
                return struct {
                    var id: TypeId = .None;
                };
            }
            
            var counter: usize = 0;
            
        };
        
    };
    
};

pub fn SparseSet(comptime T: type) type {
    
    
    return struct {
        const Self = @This();
        
        dense: []T = &[_]T{},
        sparse: []T = &[_]T{},
        dcapacity: usize = 0,
        
        const index_offset = std.math.absCast(std.math.minInt(T)); // Support for signed integers.
        
        pub fn contains(self: Self, value: T) bool {
            @setRuntimeSafety(false);
            const in_range = value < self.sparse.len;
            return in_range and self.dense[(self.sparse[ @intCast(usize, value + index_offset) ])] == value;
        }
        
        pub fn add(self: *Self, allocator: *std.mem.Allocator, value: T) !void {
            
            const new_len = self.dense.len + 1;
            self.dense.len = self.dcapacity;
            self.dense = try allocator.reallocAdvanced(self.dense, null, new_len, .at_least);
            
            self.dcapacity = self.dense.len;
            self.dense.len = new_len;
            
            
            
        }
        
    };
    
}
