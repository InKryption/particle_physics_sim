const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
    defer _ = gpa.deinit();
    
    //var mempool = std.heap.FixedBufferAllocator.init(try gpa.allocator.alloc(u8, 16_384));
    //defer gpa.allocator.free(mempool.buffer);
    
    var reg: BasicEntityRegistry = .{};
    defer reg.deinit(&gpa.allocator);
    
    const ent1 = reg.create();
    
    try reg.emplace(&gpa.allocator, ent1, u16, 32);
    
    std.debug.print("{}\n", .{reg.get(ent1, u16).?.*});
    
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

const BasicEntityRegistry = struct {
    components: Components = .{},
    
    pub fn create(self: @This()) Entity {
        return Entity.generate();
    }
    
    pub fn emplace(self: *@This(), allocator: *std.mem.Allocator, entity: Entity, comptime T: type, value: T) !void {
        try self.components.addTypes(allocator, &[_]type{T});
        
        const byte_array = self.components.getByteArrayOf(T);
        const old_len = byte_array.items.len;
        const new_len = std.math.max((entity.asNum() + 1) * @sizeOf(T), byte_array.items.len);
        try byte_array.resize(allocator, new_len);
        
        self.components.getTypeSliceOf(T)[entity.asNum()] = value;
        
    }
    
    pub fn get(self: *@This(), entity: Entity, comptime T: type) ?*T {
        const doesnt_exist = self.components.list.items.len <= Components.TypeId.of(T).asNum();
        const not_in_slice = doesnt_exist or self.components.getTypeSliceOf(T).len <= entity.asNum();
        
        if (doesnt_exist or not_in_slice) return null;
        return &self.components.getTypeSliceOf(T)[entity.asNum()];
        
    }
    
    const Entity = enum(usize) {
        _,
        
        pub fn generate() Entity {
            const Static = struct {
                var counter: usize = 0;
            };
            
            const out = Static.counter;
            Static.counter += 1;
            
            return @intToEnum(Entity, out);
        }
        
        pub fn asNum(self: Entity) @typeInfo(@This()).Enum.tag_type {
            return @enumToInt(self);
        }
        
    };
    
    pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
        self.components.deinit(allocator);
    }
    
    const Components = struct {
        list: ComponentList = .{},
        
        const ListOfComponentBytes = std.ArrayListUnmanaged(u8);
        const ComponentList = std.ArrayListUnmanaged(ListOfComponentBytes);
        
        /// Deinitialize the component listing, and all of the component arrays.
        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            
            for (self.list.items) |*component_list| {
                component_list.deinit(allocator);
            }
            
            self.list.deinit(allocator);
        }
        
        /// Add types, ensuring space for them, if they are not already registered.
        pub fn addTypes(self: *@This(), allocator: *std.mem.Allocator, comptime type_list: []const type) !void {
            
            const additional_capacity: usize = blk: {
                
                var blk_out: usize = 0;
                
                inline for (type_list) |Type| {
                    
                    const type_count_before = TypeId.typeCount();
                    _ = TypeId.of(Type);
                    const type_count_after = TypeId.typeCount();
                    
                    const is_new = type_count_after > type_count_before;
                    
                    blk_out += @boolToInt(is_new);
                }
                
                break :blk blk_out;
                
            };
            
            try self.list.appendNTimes(allocator, .{}, additional_capacity);
            
        }
        
        /// Get the byte array associated with a type.
        fn getByteArrayOf(self: *@This(), comptime Type: type) *ListOfComponentBytes {
            const type_idx = TypeId.of(Type).asNum();
            std.debug.assert(type_idx < self.list.items.len);
            return &self.list.items[type_idx];
        }
        
        /// Get a non-owning slice of specified registered type.
        fn getTypeSliceOf(self: *@This(), comptime Type: type) []Type {
            var out: []Type = &[_]Type{};
            
            const type_size = @sizeOf(Type);
            const byte_array = self.getByteArrayOf(Type);
            
            out.len = @divExact(byte_array.items.len, type_size);
            out.ptr = @ptrCast([*]Type, @alignCast(@alignOf(Type), byte_array.items.ptr));
            
            return out;
        }
        
        pub const TypeId = enum(usize) {
            _,
            
            pub fn of(comptime T: type) TypeId {
                
                const Static = struct {
                    var id: usize = undefined;
                    var is_new: bool = true;
                };
                
                if (Static.is_new) {
                    Static.id = registered_type_count;
                    registered_type_count += 1;
                    Static.is_new = false;
                }
                
                return @intToEnum(TypeId, Static.id);
            }
            
            pub fn asNum(self: @This()) @typeInfo(@This()).Enum.tag_type {
                return @enumToInt(self);
            }
            
            pub fn typeCount() usize {
                return registered_type_count;
            }
            
            pub fn isMostRecent(type_id: TypeId) bool {
                return type_id.asNum() + 1 == typeCount();
            }
            
            
            
            var registered_type_count: usize = 0;
            
        };
        
    };
    
};
