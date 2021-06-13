const std = @import("std");
const ink = @import("ink.zig");
const sdl = @import("sdl.zig");

usingnamespace struct {
    pub const Timer = ink.Timer;
    pub const TimeStepTracker = ink.TimeStepTracker;
    pub const SignalLogic = ink.SignalLogic;
    pub const StaticGrid = ink.StaticGrid;
};

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const general_purpose_allocator = &gpa.allocator;
    
    var game: Game = game_init: {
        
        const app = try App.init(.{
            .sdl_subsystems = .{.everything = true},
            .img_subsystems = .{},
            .window = .{.w = 1920 / 2, .h = 1080 / 2, .resizable = true},
            .renderer = .{},
        });
        errdefer app.deinit();
        
        break :game_init Game {
            .app = app,
            .allocator = general_purpose_allocator,
            .grid = try Game.Grid.init(general_purpose_allocator, @intCast(usize, app.context.wnd.getSize().w) / 2, @intCast(usize, app.context.wnd.getSize().h) / 2),
            .visual_config = .{
                .origin = .{.x = 0, .y = 0},
                .cells = .{.w = 2, .h = 2},
                .separation = .{.w = 0, .h = 0},
            },
        };
        
    };
    defer game.deinit();
    
    var timer = ink.Timer(.Milliseconds){};
    mainloop: while (true) {
        
        while (game.app.event.poll()) |event| switch(event.id) {
            .quit => break :mainloop,
            .mousewheel => {
                const wheel = event.data.wheel;
                game.brush.scroll(wheel.y);
                std.debug.print("{}\n", .{game.brush.get().*});
            },
            else => {},
        };
        game.app.input.mouse.update();
        
        timer.captureEnd();
        const last_frame_duration = timer.time();
        if (last_frame_duration > 16) {
            timer.captureBegin();
        } else continue :mainloop;
        
        
        
        
        try game.app.context.rnd.drawColor(sdl.Color.black);
        try game.app.context.rnd.drawClear();
        
        try game.update();
        
        game.app.context.rnd.drawUpdate();
    }
}

const Game = struct {
    app: App,
    
    grid: Grid,
    next_frame: Grid = .{
        .array_list = .{},
        .cols = 1,
    },
    
    brush: Brush = .{},
    visual_config: VisualConfig,
    allocator: *std.mem.Allocator,
    rng: std.rand.Xoroshiro128 = std.rand.Xoroshiro128.init(127),
    
    mouse_signals: struct {
        lmb: ink.SignalLogic = .{},
        rmb: ink.SignalLogic = .{},
        mmb: ink.SignalLogic = .{},
    } = .{},
    
    pub fn deinit(self: *Game) void {
        self.app.deinit();
        self.grid.deinit(self.allocator);
    }
    
    
    pub fn update(self: *Game) !void {
        
        mouse_update: {
            self.app.input.mouse.update();
            self.mouse_signals.lmb.update(self.app.input.mouse.left);
            self.mouse_signals.rmb.update(self.app.input.mouse.right);
            self.mouse_signals.mmb.update(self.app.input.mouse.middle);
        break :mouse_update;}
        
        try self.next_frame.array_list.ensureTotalCapacity(self.allocator, self.grid.size());
        try self.next_frame.array_list.resize(self.allocator, self.grid.size());
        self.next_frame.cols = self.grid.cols;
        std.mem.copy(Cell, self.next_frame.array_list.items, self.grid.array_list.items);
        
        for (self.grid.array_list.items) |*current_cell, current_cell_idx| {
            const current_coord = self.grid.indexToCoord(current_cell_idx);
            const real_position = self.visual_config.realPositionOf(current_coord.x, current_coord.y);
            
            paint_brush: {
                
                const mouse_state = self.app.input.mouse;
                const mouse_align_horizontal = mouse_state.x >= real_position.x and mouse_state.x <= real_position.x + self.visual_config.cells.w;
                const mouse_align_vertical   = mouse_state.y >= real_position.y and mouse_state.y <= real_position.y + self.visual_config.cells.h;
                
                if (mouse_align_horizontal and mouse_align_vertical and (self.mouse_signals.rmb.turnsOn() or mouse_state.left)) {
                    self.next_frame.at(current_coord.x, current_coord.y).* = self.brush.get().*;
                }
                
            break :paint_brush; }
            
            try current_cell.draw(self, current_cell_idx);
            try current_cell.update(self, current_cell_idx);
        }
        
        std.mem.copy(Cell, self.grid.array_list.items, self.next_frame.array_list.items);
        
    }
    
    
    
    const Brush = struct {
        index: usize = 0,
        
        pub fn get(self: @This()) *const Cell {
            return &paints[self.index];
        }
        
        pub fn scroll(self: *@This(), n: isize) void {
            if (n < 0) {
                self.index = self.index + (@boolToInt(self.index == 0) * paints.len) - 1;
            }
            if (n > 0) {
                self.index += 1;
                self.index %= paints.len;
            }
        }
        
        const paints = [_]Cell{
            .{ .Empty = .{} },
            .{ .Stone = .{} },
            .{ .Sand  = .{} },
            .{ .Water  = .{} },
        };
        comptime {
            inline for(@typeInfo(std.meta.TagType(Cell)).Enum.fields) |field, field_idx| {
                std.debug.assert(@enumToInt(@as(std.meta.TagType(Cell), paints[field_idx])) == field.value);
            }
            std.debug.assert(paints.len == @typeInfo(Cell).Union.fields.len);
        }
        
    };
    
    const VisualConfig = struct {
        origin:     struct{x: usize, y: usize},
        cells:      struct{w: usize, h: usize},
        separation: struct{w: usize, h: usize},
        
        pub fn realPositionOf(self: @This(), x: usize, y: usize) struct{x: usize, y: usize} {
            return .{
                .x = self.origin.x + x * self.cells.w + @divTrunc(self.separation.w * (x + 1), 2),
                .y = self.origin.y + y * self.cells.h + @divTrunc(self.separation.h * (y + 1), 2),
            };
        }
        
    };
    
    pub const Grid = struct {
        const ContainerType = std.ArrayListUnmanaged(Cell);
        array_list: ContainerType,
        cols: usize,
        
        pub fn init(allocator: *std.mem.Allocator, _width: usize, _height: usize) !Grid {
            std.debug.assert(_width * _height != 0);
            var array_list: ContainerType = try ContainerType.initCapacity(allocator, _width * _height);
            try array_list.resize(allocator, _width * _height);
            
            for (array_list.items) |*item| {
                item.* = .{.Empty = .{}};
            }
            
            return Grid {
                .cols = _width,
                .array_list = array_list,
            };
        }
        
        pub fn deinit(self: *@This(), allocator: *std.mem.Allocator) void {
            self.array_list.deinit(allocator);
        }
        
        
        
        pub fn at(self: *@This(), x: usize, y: usize) *Cell {
            const coord = Coord{.x = x, .y = y};
            return &self.array_list.items[coord.indexFor(.{.width = self.width()})];
        }
        
        pub fn get(self: *const @This(), x: usize, y: usize) *const Cell {
            return &self.array_list.items[self.indexFromCoord(x, y)];
        }
        
        
        
        pub fn size(self: @This())   usize { return self.array_list.items.len; }
        pub fn width(self: @This())  usize { return self.cols; }
        pub fn height(self: @This()) usize { return self.size() / self.width(); }
        
        pub fn indexToCoord(self: @This(), idx: usize) Coord {
            return Coord.from(idx, self.width());
        }
        
    };
    pub const Coord = struct {
        x: usize, y: usize,
        
        const Width = struct{ width: usize };
        const Height = struct{ height: usize };
        const Size = struct{ width: usize, height: usize };
        
        pub fn from(idx: usize, width: usize) Coord {
            return Coord {
                .x = idx % width,
                .y = idx / width,
            };
        }
        
        pub fn indexFor(self: @This(), param: Width) usize {
            return self.x + self.y * param.width;
        }
        
        pub fn isNorthEdge(self: @This()) bool {
            return self.y == 0;
        }
        
        pub fn isWestEdge(self: @This()) bool {
            return self.x == 0;
        }
        
        pub fn isSouthEdge(self: @This(), param: Height) bool {
            return self.y >= (param.height - 1);
        }
        
        pub fn isEastEdge(self: @This(), param: Width) bool {
            return self.x >= (param.width - 1);
        }
        
        pub fn isNorthWestEdge(self: @This()) bool {
            return self.isNorthEdge() and self.isWestEdge();
        }
        
        pub fn isNorthEastEdge(self: @This(), param: Width) bool {
            return self.isNorthEdge() and self.isEastEdge(.{ .width = param.width });
        }
        
        pub fn isSouthWestEdge(self: @This(), param: Height) bool {
            return self.isSouthEdge(.{.height = param.height}) and self.isWestEdge();
        }
        
        pub fn isSouthEastEdge(self: @This(), param: Size) bool {
            return self.isSouthEdge(.{.height = param.height})    and self.isEastEdge(.{.width = param.width});
        }
        
        
        /// Returns the Coordinate north to this one if it exists, null otherwise.
        pub fn north(self: @This()) ?Coord {
            return if (self.isNorthEdge())
            null else .{ .x = self.x, .y = self.y - 1 };
        }
        
        /// Returns the Coordinate south to this one if it exists, null otherwise.
        pub fn south(self: @This(), param: Height) ?Coord {
            return if (self.isSouthEdge(.{.height = param.height}))
            null else .{ .x = self.x, .y = self.y + 1 };
        }
        
        /// Returns the Coordinate west to this one if it exists, null otherwise.
        pub fn west(self: @This()) ?Coord {
            return if (self.isWestEdge())
            null else .{ .x = self.x - 1, .y = self.y };
        }
        
        /// Returns the Coordinate east to this one if it exists, null otherwise.
        pub fn east(self: @This(), param: Width) ?Coord {
            return if (self.isEastEdge(.{.width = param.width}))
            null else .{ .x = self.x + 1, .y = self.y };
        }
        
        /// Returns the Coordinate north-east to this one if it exists, null otherwise.
        pub fn northEast(self: @This(), param: Width) ?Coord {
            const north_y = if (self.north()) |north_coord| north_coord.y else return null;
            const east_x = if (self.east(.{.width = param.width})) |east_coord| east_coord.x else return null;
            return Coord {.x = east_x, .y = north_y};
        }
        
        /// Returns the Coordinate north-west to this one if it exists, null otherwise.
        pub fn northWest(self: @This()) ?Coord {
            const north_y = if (self.north(grid)) |north_coord| north_coord.y else return null;
            const west_x = if (self.west(grid)) |west_coord| west_coord.x else return null;
            return Coord {.x = west_x, .y = north_y};
        }
        
        /// Returns the Coordinate south-east to this one if it exists, null otherwise.
        pub fn southEast(self: @This(), param: Size) ?Coord {
            const south_y = if (self.south(.{.height = param.height})) |south_coord| south_coord.y else return null;
            const east_x = if (self.east(.{.width = param.width})) |east_coord| east_coord.x else return null;
            return Coord {.x = east_x, .y = south_y};
        }
        
        /// Returns the Coordinate south-west to this one if it exists, null otherwise.
        pub fn southWest(self: @This(), param: Height) ?Coord {
            const south_y = if (self.south(.{.height = param.height})) |south_coord| south_coord.y else return null;
            const west_x = if (self.west()) |west_coord| west_coord.x else return null;
            return Coord {.x = west_x, .y = south_y};
        }
        
    };
    
    
    
    pub const Cell = union(enum) {
        Empty: Empty,
        Stone: Stone,
        Sand: Sand,
        Water: Water,
        
        const Empty = struct {
            garbage: u1 = 0,
            fn draw(self: *const @This(), game: *const Game, self_idx: usize) !void {
                const rnd = game.app.context.rnd;
                const coord = game.grid.indexToCoord(self_idx);
                const pos = game.visual_config.realPositionOf(coord.x, coord.y);
                const size = game.visual_config.cells;
                
                try rnd.drawColor(.{.r = 55, .g = 55, .b = 55});
                try rnd.drawRect(.i, .{
                        .x = @intCast(c_int, pos.x),
                        .y = @intCast(c_int, pos.y),
                        .w = @intCast(c_int, size.w),
                        .h = @intCast(c_int, size.h)
                    }, .Empty
                );
                
            }
            
            fn update(obj: *@This(), game: *Game, self_idx: usize) !void {}
            
        };
        
        const Stone = struct {
            fn draw(self: *const @This(), game: *const Game, self_idx: usize) !void {
                const rnd = game.app.context.rnd;
                const coord = game.grid.indexToCoord(self_idx);
                const pos = game.visual_config.realPositionOf(coord.x, coord.y);
                const size = game.visual_config.cells;
                
                try rnd.drawColor(.{.r = 255 / 2, .g = 255 / 2, .b = 255 / 2});
                try rnd.drawRect(.i, .{
                        .x = @intCast(c_int, pos.x),
                        .y = @intCast(c_int, pos.y),
                        .w = @intCast(c_int, size.w),
                        .h = @intCast(c_int, size.h)
                    }, .Full
                );
                
            }
            
            fn update(obj: *@This(), game: *Game, self_idx: usize) !void {}
            
        };
        
        const Sand = struct {
            
            pub fn update(self: *@This(), game: *Game, self_idx: usize) !void {
                const random_n = game.rng.random.intRangeAtMost(u8, 0, 10);
                
                const grid_width = .{.width = game.grid.width()};
                const grid_height = .{.height = game.grid.height()};
                
                const coord = game.grid.indexToCoord(self_idx);
                const coord_south = coord.south(grid_height) orelse return;
                
                const cell_dst_coord = switch(random_n) {
                    0...8 => coord_south,
                    9     => coord_south.east(grid_width) orelse return,
                    10    => coord_south.west() orelse return,
                    else => unreachable,
                };
                
                const this_cell: *Cell = game.next_frame.at(coord.x, coord.y);
                const cell_dst: *Cell = game.next_frame.at(cell_dst_coord.x, cell_dst_coord.y);
                switch(cell_dst.*) {
                    .Empty, .Water => swapCells(cell_dst, this_cell),
                    else => {},
                }
                
            }
            
            pub fn draw(self: *const @This(), game: *const Game, self_idx: usize) !void {
                
                const rnd = game.app.context.rnd;
                const coord = game.grid.indexToCoord(self_idx);
                const pos = game.visual_config.realPositionOf(coord.x, coord.y);
                const size = game.visual_config.cells;
                
                try rnd.drawColor(sdl.Color.yellow);
                try rnd.drawRect(.i, .{
                        .x = @intCast(c_int, pos.x),
                        .y = @intCast(c_int, pos.y),
                        .w = @intCast(c_int, size.w),
                        .h = @intCast(c_int, size.h)
                    }, .Full
                );
                
            }
            
        };
        
        const Water = struct {
            
            pub fn update(self: *@This(), game: *Game, self_idx: usize) !void {
                const random_n = game.rng.random.intRangeAtMost(u8, 1, 30);
                
                const grid_width = .{.width = game.grid.width()};
                const grid_height = .{.height = game.grid.height()};
                const grid_size = .{.width = grid_width.width, .height = grid_height.height};
                
                const coord = game.grid.indexToCoord(self_idx);
                
                const potential_cell_dst_coord = switch(random_n) {
                    01...10   => coord.south(grid_height),
                    11...20   => coord.southEast(grid_size),
                    21...30   => coord.southWest(grid_height),
                    else => unreachable,
                };
                
                const potential_adj_cell_dst_coord = switch(random_n) {
                    01...15 => coord.west(),
                    16...30 => coord.east(grid_width),
                    else => unreachable,
                };
                const this_cell = game.next_frame.at(coord.x, coord.y);
                
                if (potential_cell_dst_coord) |cell_dst_coord| {
                    const dest_cell = game.next_frame.at(cell_dst_coord.x, cell_dst_coord.y);
                    switch(dest_cell.*) {
                        .Empty => { swapCells(this_cell, dest_cell); return; },
                        else => {},
                    }
                }
                
                if (potential_adj_cell_dst_coord) |cell_dst_coord| {
                    const dest_cell = game.next_frame.at(cell_dst_coord.x, cell_dst_coord.y);
                    switch(dest_cell.*) {
                        .Empty => swapCells(this_cell, dest_cell),
                        else => {},
                    }
                }
                
            }
            
            pub fn draw(self: *const @This(), game: *const Game, self_idx: usize) !void {
                
                const rnd = game.app.context.rnd;
                const coord = game.grid.indexToCoord(self_idx);
                const pos = game.visual_config.realPositionOf(coord.x, coord.y);
                const size = game.visual_config.cells;
                
                try rnd.drawColor(sdl.Color.blue);
                try rnd.drawRect(.i, .{
                        .x = @intCast(c_int, pos.x),
                        .y = @intCast(c_int, pos.y),
                        .w = @intCast(c_int, size.w),
                        .h = @intCast(c_int, size.h)
                    }, .Full
                );
                
            }
            
        };
        
        pub fn update(self: *@This(), game: *Game, self_idx: usize) !void {
            switch(self.*) {
                .Empty       => |*cell| try cell.update(game, self_idx),
                .Stone       => |*cell| try cell.update(game, self_idx),
                .Sand        => |*cell| try cell.update(game, self_idx),
                .Water       => |*cell| try cell.update(game, self_idx),
            }
        }
        
        pub fn draw(self: *const @This(), game: *const Game, self_idx: usize) !void {
            switch(self.*) {
                .Empty =>           |*cell| try cell.draw(game, self_idx),
                .Stone =>           |*cell| try cell.draw(game, self_idx),
                .Sand =>            |*cell| try cell.draw(game, self_idx),
                .Water =>           |*cell| try cell.draw(game, self_idx),
            }
            
        }
        
        pub fn swapCells(a: *Cell, b: *Cell) void {
            const copy = b.*;
            b.* = a.*;
            a.* = copy;
        }
        
    };
    
};

const App = struct {
    
    context: Context,
    input: Input,
    event: sdl.Event,
    
    pub fn init(context_config: Context.Config) !App {
        
        const context = try Context.init(context_config);
        errdefer context.deinit();
        
        const input = Input.init();
        errdefer input.deinit();
        
        const event = sdl.Event{};
        
        return App {
            .context = context,
            .input = input,
            .event = event,
        };
        
    }
    
    pub fn deinit(self: App) void {
        self.input.deinit();
        self.context.deinit();
    }
    
    const Context = struct {
        wnd: sdl.Window,
        rnd: sdl.Renderer,
        
        const Config = struct {
            sdl_subsystems: sdl.Subsystems,
            img_subsystems: sdl.ImgSubsystems,
            window: sdl.Window.Ctr,
            renderer: sdl.Renderer.Ctr,
        };
        
        pub fn init(config: Config) !Context {
            
            try sdl.init(config.sdl_subsystems, config.img_subsystems);
            errdefer sdl.deinit();
            
            const wnd = try sdl.Window.init(config.window);
            errdefer wnd.deinit();
            
            const rnd = try wnd.createRenderer(config.renderer);
            errdefer rnd.deinit();
            
            return Context {.wnd = wnd, .rnd = rnd};
            
        }
        
        pub fn deinit(self: Context) void {
            self.rnd.deinit();
            self.wnd.deinit();
            sdl.deinit();
        }
        
    };
    
    const Input = struct {
        const Keyboard = sdl.Keyboard;
        mouse: sdl.Mouse,
        
        pub fn init() Input {
            return .{ .mouse = sdl.Mouse.init() };
        }
        
        pub fn scanCode(self: @This(), sc: Keyboard.Scancode) bool {
            return Keyboard.scanCode(sc);
        }
        
        pub fn update(self: *@This()) void {
            self.mouse.update();
        }
        
        pub fn deinit(self: @This()) void {}
    };
    
};


/// Second draft of physics sim. Third draft to be cleaner (hopefully).
const old = struct {

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
            
            //_ = ink.IteratorInterface(.{});
            
            if (!time_step) continue :mainloop;
            
            if (context.mouse.left) {
                
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
            
            try Brush.get().draw(sandbox.*, .{.x = SandboxType.GridType.width, .y = 0});
            
            for (sandbox.grid.cells) |current_cell, current_cell_idx| {
                const current_coord = SandboxType.Coord.from(current_cell_idx);
                try current_cell.draw(sandbox.*, current_coord);
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
                    
                    pub fn update(self: *@This(), sandbox: *SandboxType, coord: Coord) callconv(.Inline) !void {
                        switch(self.*) {
                            .Empty => |*cell| try cell.update(sandbox, coord),
                            .Stone => |*cell| try cell.update(sandbox, coord),
                            .Sand =>  |*cell| try cell.update(sandbox, coord),
                            .Water => |*cell| try cell.update(sandbox, coord),
                        }
                    }
                    
                    pub fn draw(self: @This(), sandbox: SandboxType, coord: Coord) callconv(.Inline) !void {
                        switch(self) {
                            .Empty => |cell| try cell.draw(sandbox, coord),
                            .Stone => |cell| try cell.draw(sandbox, coord),
                            .Sand =>  |cell| try cell.draw(sandbox, coord),
                            .Water => |cell| try cell.draw(sandbox, coord),
                        }
                    }
                    
                    pub fn makeRectFrom(pos: Coord, size: VisualConfig.Size) sdl.Rect(.i) {
                        return .{
                            .x = @intCast(c_int, pos.x),
                            .y = @intCast(c_int, pos.y),
                            .w = @intCast(c_int, size.w),
                            .h = @intCast(c_int, size.h),
                        };
                    }
                    
                };
                
                const BasicIterator = struct {
                    ptr: *SandboxType,
                    idx: usize,
                };
                
                pub fn update(self: *@This()) !void {
                    
                    self.next_frame = self.grid;
                    
                    for (self.grid.cells) |*current_cell, current_idx| {
                        const current_coord = Coord.from(current_idx);
                        try current_cell.update(self, current_coord);
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
                    .mouse = Mouse.init(),
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
        
        pub const Mouse = sdl.Mouse;
        
    };
    
};
