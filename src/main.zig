const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

fn printTypeId(comptime T: type) void {
    std.debug.print("'{s}': {}\n", .{@typeName(T), ink.TypeId.of(T)});
}

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = false}){};
    defer _ = gpa.deinit();
    
    // Very simple construct that we'll use to pool memory.
    var mempool = try MemPoolAllocator.init(&gpa.allocator, 16_777_216);
    defer mempool.deinit();
    
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

const EntityCS = struct {
    
    
    const Components = struct {
        list: [][]u8,
    };
    
};

const MemPoolAllocator = struct {
    original_allocator: *std.mem.Allocator,
    allocator: *std.mem.Allocator,
    manager: std.heap.FixedBufferAllocator,
    
    pub fn init(allocator: *std.mem.Allocator, n: usize) !MemPoolAllocator {
        const new_mem = try allocator.alloc(u8, n);
        var out =  MemPoolAllocator {
            .original_allocator = allocator,
            .allocator = undefined,
            .manager = std.heap.FixedBufferAllocator.init(new_mem),
        }; out.allocator = &out.manager.allocator;
        return out;
    }
    
    pub fn deinit(self: *@This()) void {
        self.original_allocator.free(self.manager.buffer);
    }
    
};
