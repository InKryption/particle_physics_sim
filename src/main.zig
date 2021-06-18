const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
    defer _ = gpa.deinit();
    
    //var mempool = std.heap.FixedBufferAllocator.init(try gpa.allocator.alloc(u8, 16_384));
    //defer gpa.allocator.free(mempool.buffer);
    
    const Coord = struct {
        x: usize = 0, 
        y: usize = 0, 
        flag: bool = false
    };
    
    var reg = EntityRegistry.Components{};
    defer reg.deinit(&gpa.allocator);
    
    _ = try reg.addType(&gpa.allocator, Coord, 1);
    const m = reg.getType(Coord).?;
    m.items.ptr[0].x = 0;
    m.items.ptr[0].y = 2;
    m.items.ptr[0].flag = true;
    std.debug.print("{}\n", .{m.items.ptr[0]});
    
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
    components: Components,
    
    const Components = struct {
        list: std.ArrayListUnmanaged( std.ArrayListUnmanaged(u8) ) = .{},
        
        
        
        const ComponentError = error {
            ComponentDoesntExist,
            ComponentAlreadyExists,
        };
        
        
        
        fn addType(self: *@This(), allocator: *std.mem.Allocator, comptime T: type, init_capacity: usize) !void {
            
            const type_id = TypeId.of(T);
            
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
            
            out.items.ptr = @intToPtr([*]T, @ptrToInt(byte_array.items.ptr));
            out.items.len = byte_array.items.len / @sizeOf(T);
            out.capacity = byte_array.capacity / @sizeOf(T);
            
            return out;
            
        }
        
        
        
        fn updateBytes(self: *@This(), comptime T: type, with: std.ArrayListUnmanaged(T)) !void {
            
            const byte_array = self.getBytes(T) orelse return ComponentError.ComponentDoesntExist;
            
            byte_array.items.len = with.items.len * @sizeOf(T);
            byte_array.capacity = with.capacity * @sizeOf(T);
            
        }
        
        fn getBytes(self: *@This(), comptime T: type) ?*std.ArrayListUnmanaged(u8) {
            
            const type_id = TypeId.of(T);
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
            _,
            
            pub fn value(self: TypeId) usize {
                return @enumToInt(self);
            }
            
            pub fn of(comptime T: type) TypeId {
                
                const Static = struct {
                    var id: usize = undefined;
                    var is_new: bool = true;
                };
                
                if (Static.is_new) {
                    Static.is_new = false;
                    Static.id = counter;
                    counter += 1;
                }
                
                return @intToEnum(TypeId, Static.id);
                
            }
            
            pub fn count() usize {
                return counter;
            }
            
            var counter: usize = 0;
            
        };
        
    };
    
};
