const std = @import("std");
const mem = std.mem;

pub const SignalLogic = struct {
    const Self = @This();
    
    prev: bool = false,
    curr: bool = false,
    
    pub fn update(self: *Self, signal: bool) void {
        self.prev = self.curr;
        self.curr = signal;
    }
    
    pub fn current(self: Self)  bool { return  self.curr               ; }
    pub fn previous(self: Self) bool { return                 self.prev; }
    
    pub fn inactive(self: Self) bool { return !self.curr and !self.prev; }
    pub fn active(self: Self)   bool { return  self.curr and  self.prev; }
    
    pub fn turnsOn(self: Self)  bool { return  self.curr and !self.prev; }
    pub fn turnsOff(self:Self)  bool { return !self.curr and  self.prev; }
    
};

pub const TimePrecision = enum {
    Seconds,
    Milliseconds,
    Nanoseconds,
};

pub fn Timer(comptime precision_type: TimePrecision) type {
    return struct {
        
        begin: ValueType = 0,
        end: ValueType = 0,
        
        pub fn captureBegin(self: *@This()) void      { self.begin = getTimeFunc();  }
        pub fn captureEnd(self: *@This())   void      { self.end   = getTimeFunc();  }
        pub fn time(self: @This())          ValueType { return self.end - self.begin; }
        
        pub const ValueType = @typeInfo(@TypeOf(getTimeFunc)).Fn.return_type.?;
        pub const precision = precision_type;
        pub const getTimeFunc = switch(precision_type) {
            .Seconds      => std.time.timestamp,
            .Milliseconds => std.time.milliTimestamp,
            .Nanoseconds  => std.time.nanoTimestamp,
        };
        
    };
}


/// Wrapper around an array which is (grid_width * grid_height) Ts in size,
/// where it can be treated as a 2D Grid of sorts.
pub fn StaticGrid(comptime T: type, comptime grid_width: usize, comptime grid_height: usize) type {
    return struct {
        const Self = @This();
        
        cells: [size]T,
        
        pub fn initWithValue(value: T) Self {
            return Self {
                .cells = .{value} ** size,
            };
        }
        
        pub fn initWithRow(row: [width]T) Self {
            var out: Self = .{ .cells = .{@as(T, undefined)} ** size };
            
            for (out.cells) |*item, i| {
                item.* = row[i % grid_width];
            }
            
            return out;
        }
        
        pub fn initWithCol(col: [height]T) Self {
            var out: Self = .{ .cells = .{@as(T, undefined)} ** size };
            
            for (out.cells) |*item, i| {
                item.* = col[i / grid_width];
            }
            
            return out;
        }
        
        /// Returns a mutable pointer to the cell at the specified coordinate.
        pub fn at(self: *Self, coord: Coord) *T {
            return &self.cells[coord.idx()];
        }
        
        /// Returns an immutable pointer to the cell at the specified coordinate.
        pub fn get(self: *const Self, coord: Coord) *const T {
            return &self.cells[coord.idx()];
        }
        
        /// Return a mutable slice that ranges from coordinates (0, y) to (width, y), hence a row.
        pub fn atRowSlice(self: *Self, y: usize) []T {
            const coord = Coord{.x = 0, .y = y};
            return self.cells[coord.idx()..width];
        }
        
        /// Return a view slice that ranges from coordinates (0, y) to (width, y), hence a row.
        pub fn getRowSlice(self: Self, y: usize) []const T {
            const coord = Coord{.x = 0, .y = y};
            return self.cells[coord.idx()..width];
        }
        
        
        
        pub fn atCol(self: *@This(), x: usize) ColView(true) {
            return .{
                .ptr = self,
                .x = x,
            };
        }
        
        pub fn getCol(self: *const @This(), x: usize) ColView(false) {
            return .{
                .ptr = self,
                .x = x,
            };
        }
        
        pub fn atRow(self: *@This(), y: usize) RowView(true) {
            return .{
                .ptr = self,
                .y = y,
            };
        }
        
        pub fn getRow(self: *const @This(), y: usize) RowView(false) {
            return .{
                .ptr = self,
                .y = y,
            };
        }
        
        pub const size = width * height;
        pub const width = grid_width;
        pub const height = grid_height;
        
        fn ColView(comptime is_mut: bool) type {
            return struct {
                ptr: if (is_mut) *Grid else *const Grid,
                x: usize,
                
                pub fn at(self: *@This(), y: usize) *T {
                    const coord = Coord{.x = self.x, .y = y};
                    return &self.ptr.cells.items[coord.idx()];
                }
                
                pub fn get(self: @This(), y: usize) *const T {
                    const coord = Coord{.x = self.x, .y = y};
                    return self.ptr.cells.items[coord.idx()];
                }
                
            };
        }
        
        fn RowView(comptime is_mut: bool) type {
            return struct {
                ptr: if (is_mut) *Grid else *const Grid,
                y: usize,
                
                pub fn at(self: *@This(), x: usize) *T {
                    const coord = Coord{.x = x, .y = self.y};
                    return &self.ptr.cells.items[coord.idx()];
                }
                
                pub fn get(self: @This(), x: usize) *const T {
                    const coord = Coord{.x = x, .y = self.y};
                    return &self.ptr.cells.items[coord.idx()];
                }
                
            };
        }
        
        pub const Coord = struct {
            x: usize, y: usize,
            
            pub fn from(i: usize) @This() { return .{ .x = i % width, .y = i / width }; }
            pub fn idx(self: @This()) usize { return self.x + (self.y * width); }
            
            pub fn isNorthEdge(self: @This())     bool { return self.y == 0;            }
            pub fn isSouthEdge(self: @This())     bool { return self.y == (height - 1); }
            pub fn isWestEdge(self: @This())      bool { return self.x == 0;            }
            pub fn isEastEdge(self: @This())      bool { return self.x == (width - 1);  }
            
            pub fn isNorthWestEdge(self: @This()) bool { return self.isNorthEdge() and self.isWestEdge(); }
            pub fn isNorthEastEdge(self: @This()) bool { return self.isNorthEdge() and self.isEastEdge(); }
            pub fn isSouthWestEdge(self: @This()) bool { return self.isSouthEdge() and self.isWestEdge(); }
            pub fn isSouthEastEdge(self: @This()) bool { return self.isSouthEdge() and self.isEastEdge(); }
            
            /// Returns the Coordinate north to this one if it exists, null otherwise.
            pub fn north(self: @This()) ?Coord {
                return if (self.isNorthEdge())
                null else .{ .x = self.x, .y = self.y - 1 };
            }
            
            /// Returns the Coordinate south to this one if it exists, null otherwise.
            pub fn south(self: @This()) ?Coord {
                return if (self.isSouthEdge())
                null else .{ .x = self.x, .y = self.y + 1 };
            }
            
            /// Returns the Coordinate west to this one if it exists, null otherwise.
            pub fn west(self: @This()) ?Coord {
                return if (self.isWestEdge())
                null else .{ .x = self.x - 1, .y = self.y };
            }
            
            /// Returns the Coordinate east to this one if it exists, null otherwise.
            pub fn east(self: @This()) ?Coord {
                return if (self.isEastEdge())
                null else .{ .x = self.x + 1, .y = self.y };
            }
            
            /// Returns the Coordinate north-east to this one if it exists, null otherwise.
            pub fn northEast(self: @This()) ?Coord {
                const north_y = if (self.north()) |north_coord| north_coord.y else return null;
                const east_x = if (self.east()) |east_coord| east_coord.x else return null;
                return Coord {.x = east_x, .y = north_y};
            }
            
            /// Returns the Coordinate north-west to this one if it exists, null otherwise.
            pub fn northWest(self: @This()) ?Coord {
                const north_y = if (self.north()) |north_coord| north_coord.y else return null;
                const west_x = if (self.west()) |west_coord| west_coord.x else return null;
                return Coord {.x = west_x, .y = north_y};
            }
            
            /// Returns the Coordinate south-east to this one if it exists, null otherwise.
            pub fn southEast(self: @This()) ?Coord {
                const south_y = if (self.south()) |south_coord| south_coord.y else return null;
                const east_x = if (self.east()) |east_coord| east_coord.x else return null;
                return Coord {.x = east_x, .y = south_y};
            }
            
            /// Returns the Coordinate south-west to this one if it exists, null otherwise.
            pub fn southWest(self: @This()) ?Coord {
                const south_y = if (self.south()) |south_coord| south_coord.y else return null;
                const west_x = if (self.west()) |west_coord| west_coord.x else return null;
                return Coord {.x = west_x, .y = south_y};
            }
            
            /// Unconditionally returns the Coordinate north to this one, wrapping around to the most southern coordinate if null.
            pub fn northWrap(self: @This()) Coord {
                return if (self.north()) |n|
                n else .{ .x = self.x, .y = height - 1 };
            }
            
            /// Unconditionally returns the Coordinate south to this one, wrapping around to the most northern coordinate if null.
            pub fn southWrap(self: @This()) Coord {
                return if (self.south()) |s|
                s else .{ .x = self.x, .y = 0 };
            }
            
            /// Unconditionally returns the Coordinate west to this one, wrapping around to the most eastern coordinate if null.
            pub fn westWrap(self: @This()) Coord {
                return if (self.west()) |w|
                w else .{ .x = width - 1, .y = self.y };
            }
            
            /// Unconditionally returns the Coordinate east to this one, wrapping around to the most western coordinate if null.
            pub fn eastWrap(self: @This()) Coord {
                return if (self.east()) |w|
                w else .{ .x = 0, .y = self.y };
            }
            
            pub fn surrounding(self: @This()) [9]?Coord {
                return .{
                    self.northWest(), self.north(), self.northEast(),
                    self.west(),      null,         self.east(),
                    self.southWest(), self.south(), self.southEast(),
                };
            }
            
        };
        
    };
}
