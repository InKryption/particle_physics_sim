const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

usingnamespace struct {
    pub const Timer = ink.Timer;
    pub const TimeStepTracker = ink.TimeStepTracker;
    pub const SignalLogic = ink.SignalLogic;
    pub const StaticGrid = ink.StaticGrid;
};

pub fn main() anyerror!void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const general_allocator = &gpa.allocator;
    
    const playing_field_setup = .{
        .w = @as(usize, 1920 * 0.5),
        .h = @as(usize, 1080 * 0.5),
    };
    
    var context = try game.Context.init(.{
        .subsystems = .{},
        .img_subsystems = .{},
        .window = .{.w = playing_field_setup.w, .h = playing_field_setup.h, .resizable = true},
        .renderer = .{}
    }); defer context.deinit();
    
    const SandboxType = game.Sandbox(playing_field_setup.w / 10 - 1, playing_field_setup.h / 10);
    const sandbox = try general_allocator.create(SandboxType);
    defer general_allocator.destroy(sandbox);
    sandbox.* = SandboxType {
        .context = &context,
        .visual_config = .{
            .origin =     .{.x = 0, .y = 0},
            .separation = .{.w = 0, .h = 0},
            .cell_size =  .{.w = 10, .h = 10},
        },
        .rng = SandboxType.Rng.init(std.math.absCast(std.time.milliTimestamp())),
    };
    
    // Singleton struct representing the brush.
    const Brush = struct {
        
        pub fn get() *const SandboxType.Cell{
            return &brush_array[brush_index];
        }
        
        pub fn scroll(n: i64) void {
            if (n < 0) {
                brush_index = brush_index + (@boolToInt(brush_index == 0) * brush_array.len) - 1;
            }
            if (n > 0) {
                brush_index += 1;
                brush_index %= brush_array.len;
            }
        }
        
        var brush_index: usize = 0;
        const brush_array = [_]SandboxType.Cell{
            .{.Empty = .{}},
            .{.Stone = .{}},
            .{.Sand  = .{}},
            .{.Water = .{}},
        };
        
    };
    
    var loop_timer: Timer(.Milliseconds) = .{};
    mainloop: while (true) : (loop_timer.captureEnd()) {     
        const time_step = loop_timer.time() > 16;
        if (time_step) loop_timer.captureBegin();
        
        context.mouse.update();
        while (context.poll()) |event| switch (event.id) {
            // Poll and handle events.
            .quit => break :mainloop,
            .mousewheel, => Brush.scroll(event.data.wheel.y),
            else => {}
        };
        
        
        if (!time_step) continue :mainloop;
        
        if (context.mouse.lb.active() or context.mouse.rb.turnsOn()) {
            
            for (sandbox.grid.cells) |*current_cell, current_cell_idx| {
                const current_coord = SandboxType.Coord.from(current_cell_idx);
                const real_position = sandbox.visual_config.positionOf(current_coord);
                
                paint_cell_brush: {
                    
                    const mouse = context.mouse;
                    
                    const align_horizontal    = (mouse.x >= real_position.x and mouse.x <= real_position.x + sandbox.visual_config.cell_size.w);
                    const align_vertical      = (mouse.y >= real_position.y and mouse.y <= real_position.y + sandbox.visual_config.cell_size.h);
                    
                    if (align_horizontal and align_vertical)
                    { current_cell.* = Brush.get().*; }
                    
                break :paint_cell_brush;}
                
            }
            
        }
        
        try sandbox.update();
        
        try context.rnd.drawColor(sdl.Color.black);
        try context.rnd.drawClear();
        
        switch(Brush.get().*) {
            .Empty => |cell| try cell.draw(sandbox.*, .{.x = SandboxType.GridType.width, .y = 0}),
            .Stone => |cell| try cell.draw(sandbox.*, .{.x = SandboxType.GridType.width, .y = 0}),
            .Sand  => |cell| try cell.draw(sandbox.*, .{.x = SandboxType.GridType.width, .y = 0}),
            .Water => |cell| try cell.draw(sandbox.*, .{.x = SandboxType.GridType.width, .y = 0}),
        }
        
        for (sandbox.grid.cells) |current_cell, current_cell_idx| {
            const current_coord = SandboxType.Coord.from(current_cell_idx);
            
            switch(current_cell) {
                .Empty => |cell| try cell.draw(sandbox.*, current_coord),
                .Stone => |cell| try cell.draw(sandbox.*, current_coord),
                .Sand =>  |cell| try cell.draw(sandbox.*, current_coord),
                .Water => |cell| try cell.draw(sandbox.*, current_coord),
            }
            
        }
        
        context.rnd.drawUpdate();
        
    }
    
}

const game = struct {
    
    pub fn Sandbox(comptime width: usize, comptime height: usize) type {
        return struct {
            const SandboxType = @This();
            const GridType = StaticGrid(Cell, width, height);
            const Coord = GridType.Coord;
            const Rng = std.rand.Xoroshiro128;
            
            context: *Context,
            grid: GridType = GridType.initWithValue(.Empty),
            next_frame: GridType = GridType.initWithValue(.Empty),
            visual_config: VisualConfig,
            rng: Rng,
            
            pub const VisualConfig = struct {
                
                pub const Position = Coord;
                pub const Size = struct{w: usize, h: usize};
                
                origin: Position,
                separation: Size,
                cell_size: Size,
                
                pub fn positionOf(self: @This(), coord: Position) Position {
                    return .{
                        .x = self.origin.x + (coord.x * self.cell_size.w) + @divTrunc(self.separation.w * (coord.x + 1), 2),
                        .y = self.origin.y + (coord.y * self.cell_size.h) + @divTrunc(self.separation.h * (coord.y + 1), 2),
                    };
                }
                
            };
            
            pub const Cell = union(enum) {
                Empty: Empty,
                Stone: Stone,
                Sand: Sand,
                Water: Water,
                
                pub const Empty = struct {
                    
                    pub fn update(self: @This(), sandbox: *SandboxType, coord: Coord) callconv(.Inline) !void {}
                    pub fn draw(self: @This(), sandbox: SandboxType, coord: Coord) !void {
                        const rnd = sandbox.context.rnd;
                        const color = sdl.Color{.r = 10, .g = 10, .b = 10};
                        const size = sandbox.visual_config.cell_size;
                        const pos = sandbox.visual_config.positionOf(coord);
                        
                        try rnd.drawColor(color);
                        try rnd.drawRect(.i, makeRectFrom(pos, size), .Empty);
                    }
                    
                };
                
                pub const Stone = struct {
                    
                    pub fn update(self: @This(), sandbox: *SandboxType, coord: Coord) callconv(.Inline) !void {}
                    
                    pub fn draw(self: @This(), sandbox: SandboxType, coord: Coord) !void {
                        const rnd = sandbox.context.rnd;
                        const color = sdl.Color{.r = 55, .g = 55, .b = 55};
                        const size = sandbox.visual_config.cell_size;
                        const pos = sandbox.visual_config.positionOf(coord);
                        
                        try rnd.drawColor(color);
                        try rnd.drawRect(.i, makeRectFrom(pos, size), .Full);
                    }
                    
                };
                
                pub const Sand = struct {
                    
                    pub fn update(self: @This(), sandbox: *SandboxType, coord: Coord) callconv(.Inline) !void {
                        
                        const random_n = sandbox.rng.random.intRangeAtMost(u8, 0, 100);
                        const coord_south = coord.south() orelse return;
                        const south_adjacents = [_]?Coord{
                            switch (random_n) { 0...87   => coord_south,        88...93  => coord_south.east(), 94...100 => coord_south.west(), else => unreachable, },
                            switch (random_n) { 88...93  => coord_south.east(), 94...100 => coord_south.west(), 0...87   => coord_south,        else => unreachable, },
                            switch (random_n) { 94...100 => coord_south.west(), 0...87   => coord_south,        88...93  => coord_south.east(), else => unreachable, },
                        };
                        
                        const current_cell = sandbox.next_frame.at(coord);
                        
                        for (south_adjacents) |possible_southern_coord|
                        if (possible_southern_coord) |south_coord| {
                            
                            const south_cell = sandbox.next_frame.at(south_coord);
                            
                            switch(south_cell.*) {
                                .Stone, .Sand, => {},
                                .Empty, .Water => {
                                    if (south_cell.* == .Water and sandbox.rng.random.intRangeAtMost(u64, 0, 100) < 90) continue;
                                    const copy = south_cell.*;
                                    south_cell.* = current_cell.*;
                                    current_cell.* = copy;
                                    return;
                                },
                            }
                            
                        };
                        
                    }
                    
                    pub fn draw(self: @This(), sandbox: SandboxType, coord: Coord) !void {
                        const rnd = sandbox.context.rnd;
                        const color = sdl.Color.yellow;
                        const size = sandbox.visual_config.cell_size;
                        const pos = sandbox.visual_config.positionOf(coord);
                        
                        try rnd.drawColor(color);
                        try rnd.drawRect(.i, makeRectFrom(pos, size), .Full);
                    }
                    
                };
                
                pub const Water = struct {
                    
                    inline fn switchCell(sandbox: *SandboxType, coord: Coord) ?Coord {
                        const random_n = sandbox.rng.random.intRangeAtMost(u8, 0, 131);
                        
                        const range_south =      .{.l = 0, .m = 50};
                        const range_south_east = .{.l = 51, .m = 76};
                        const range_south_west = .{.l = 77, .m = 100};
                        
                        const range_west =       .{.l = 101, .m = 111};
                        const range_east =       .{.l = 112, .m = 131};
                        
                        return switch(random_n) {
                            (range_south.l     ) ... (range_south.m     ) => coord.south(),
                            (range_south_east.l) ... (range_south_east.m) => coord.southEast(),
                            (range_south_west.l) ... (range_south_west.m) => coord.southWest(),
                            (range_west.l      ) ... (range_west.m)       => coord.west(),
                            (range_east.l      ) ... (range_east.m)       => coord.east(),
                            else                                          => unreachable,
                        };
                        
                    }
                    
                    pub fn update(self: @This(), sandbox: *SandboxType, coord: Coord) callconv(.Inline) !void {
                        
                        const current_cell = sandbox.next_frame.at(coord);

                        if (switchCell(sandbox, coord)) |south_coord| {
                            
                            const south_cell = sandbox.next_frame.at(south_coord);
                            
                            switch(south_cell.*) {
                                .Empty, => {
                                    const copy = south_cell.*;
                                    south_cell.* = current_cell.*;
                                    current_cell.* = copy;
                                    return;
                                },
                                .Stone, .Sand, .Water => {},
                            }
                            
                        }
                        
                    }
                    
                    pub fn draw(self: @This(), sandbox: SandboxType, coord: Coord) !void {
                        const rnd = sandbox.context.rnd;
                        const color = sdl.Color.blue;
                        const size = sandbox.visual_config.cell_size;
                        const pos = sandbox.visual_config.positionOf(coord);
                        
                        try rnd.drawColor(color);
                        try rnd.drawRect(.i, makeRectFrom(pos, size), .Full);
                    }
                    
                };
                
                pub fn makeRectFrom(pos: Coord, size: VisualConfig.Size) sdl.Rect(.i) {
                    return .{
                        .x = @intCast(c_int, pos.x),
                        .y = @intCast(c_int, pos.y),
                        .w = @intCast(c_int, size.w),
                        .h = @intCast(c_int, size.h),
                    };
                }
                
            };
            
            pub fn update(self: *@This()) !void {
                
                self.next_frame = self.grid;
                
                for (self.grid.cells) |*current_cell, current_idx| {
                    const current_coord = Coord.from(current_idx);
                    
                    try switch(current_cell.*) {
                        .Empty => |*cell| cell.update(self, current_coord),
                        .Stone => |*cell| cell.update(self, current_coord),
                        .Sand  => |*cell| cell.update(self, current_coord),
                        .Water => |*cell| cell.update(self, current_coord),
                    };
                    
                }
                
                self.grid = self.next_frame;
                
            }
            
        };
        
    }
    
    pub const Context = struct {
        const Self = @This();
        
        wnd: sdl.Window,
        rnd: sdl.Renderer,
        evt: sdl.Event,
        mouse: Mouse,
        
        pub fn init(args: struct {
            subsystems: sdl.Subsystems,
            img_subsystems: sdl.ImgSubsystems,
            window: sdl.Window.Ctr,
            renderer: sdl.Renderer.Ctr,
        }) !Self {
            
            try sdl.init(args.subsystems, args.img_subsystems);
            const wnd = try sdl.Window.init(args.window);
            const rnd = try wnd.createRenderer(args.renderer);
            
            return Self {
                .wnd = wnd,
                .rnd = rnd,
                .evt = .{},
                .mouse = .{},
            };
            
        }
        
        pub fn deinit(self: Self) void {
            self.rnd.deinit();
            self.wnd.deinit();
            sdl.deinit();
        }
        
        pub fn poll(self: *Context) @typeInfo(@TypeOf(sdl.Event.poll)).Fn.return_type.? {
            return self.evt.poll();
        }
        
    };
    
    pub const Mouse = struct {
        x: c_int = 0,
        y: c_int = 0,
        lb: SignalLogic = .{},
        mb: SignalLogic = .{},
        rb: SignalLogic = .{},
        
        pub fn update(self: *@This()) void {
            const mouse = sdl.Mouse.get(.Relative);
            self.x = mouse.x;
            self.y = mouse.y;
            
            self.lb.update(mouse.left);
            self.mb.update(mouse.middle);
            self.rb.update(mouse.right);
            
        }
        
    };
    
};
