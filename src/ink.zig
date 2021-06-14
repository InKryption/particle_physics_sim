const std = @import("std");
const mem = std.mem;
const meta = std.meta;

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

/// Caller guarantees that `dimensions.len == coordinates.len` and `dimensions[i] != 0`.
/// 
/// Transposes `n`-dimensional coordinates to the absolute index into an array, which has a size of the product of all elements of `dimensions`,
/// where `n` is the length of the slice `dimensions`.
/// 
/// The following demonstration of usage compiles and runs:
/// ```
/// const width = 3;
/// const height = 4;
/// 
/// const size = width * height;
/// const dimensions = [_]usize{ width, height };
/// 
/// const coordinate_array = [size][]const usize {
///     .{0, 0}, .{1, 0}, .{2, 0},
///     .{0, 1}, .{1, 1}, .{2, 1},
///     .{0, 2}, .{1, 2}, .{2, 2},
/// };
/// 
/// for (coordinate_array) |coordinate, absolute_index| {
///     const eq = absolute_index == transposeCoord(usize, &dimensions, coordinate);
///     std.debug.assert(eq);
/// }
/// ```
/// 
/// The same logic follows for higher dimensions:
/// ```
/// const width = 2;
/// const height = 2;
/// const depth = 3;
/// 
/// const size = width * height * depth;
/// const dimensions = [_]usize{ width, height };
/// 
/// const coordinate_array = [size][]const usize {
///     .{0, 0, 0}, .{1, 0, 0},
///     .{0, 1, 0}, .{1, 1, 0},
/// 
///     .{0, 0, 1}, .{1, 0, 1},
///     .{0, 1, 1}, .{1, 1, 1},
/// 
///     .{0, 0, 2}, .{1, 0, 2},
///     .{0, 1, 2}, .{1, 1, 2},
/// };
/// 
/// for (coordinate_array) |coordinate, absolute_index| {
///     const eq = absolute_index == transposeCoord(usize, &dimensions, coordinate);
///     std.debug.assert(eq);
/// }
/// ```
/// Essentially, for each dimension, there is a grouping in the array.
/// The previous example could be extended to 4 dimensions, and the behaviour would follow by simply making groups that are
/// equivalent to a single instance of the above within the array.
/// 
/// It is also useful to note that each grouping can be recognized by the unchanging coordinate component.
/// For the first dimension, that is just the element itself; for the second dimension, it is the second coordinate component;
/// for the third, it is the third component; for the fourth, the fourth, and so on.
pub fn transposeCoord(
    comptime T: type,
    dimensions: []const T,
    coordinate: []const T,
) T {
    
    switch(@typeInfo(T)) {
        .Int, .Float => {},
        else => @compileError("transposeCoord: Expected numeric type, found " ++ @typeName(T) ++ ".\n"),
    }
    
    var absolute_index: T = 0;
    var space_coeficient: T = 1;
    
    for (dimensions) |space, idx| {
        const space_product = space_coeficient * space;
        const coordinate_component = coordinate[idx];
        
        absolute_index = @mod(absolute_index + coordinate_component * space_coeficient, space_product);
        space_coeficient = space_product;
    }
    
    return absolute_index;
}

/// Caller guarantees that `N < dimensions.len`
/// 
/// The inverse of `transposeCoord`.
/// 'N' refers to the index of the desired coordinate component.
pub fn transposeIndexComponent(
    comptime T: type,
    dimensions: []const T,
    N: usize,
    index: T,
) T {
    
    switch(@typeInfo(T)) {
        .Int, .Float => {},
        else => @compileError("transposeIndexComponent: Expected numeric type, found " ++ @typeName(T) ++ ".\n"),
    }
    
    const nums = blk: {
        var space_size: T = 1;
        var space_divisor: T = dimensions[N];
        
        var idx: usize = 0;
        while (idx < N) : (idx += 1) {
            space_divisor *= space_size;
            space_size *= dimensions[idx];
        }
        
        break :blk .{
            .space_size = space_size,
            .space_divisor = space_divisor,
        };
    };
    
    return @rem(@divTrunc(index, nums.space_divisor), nums.space_size);
    
}

/// Caller guarantees that `out.len >= dimensions.len`
/// 
/// Performs the same purpose as `transposeIndexComponent`, but fills in a slice with the result
/// for each coordinate component in order. The result is stored in `out`. 
pub fn transposeIndex(
    comptime T: type,
    dimensions: []const T,
    out: []T,
    index: usize,
) void {
    
    switch(@typeInfo(T)) {
        .Int, .Float => {},
        else => @compileError("transposeIndexComponent: Expected numeric type, found " ++ @typeName(T) ++ ".\n"),
    }
    
    // We have to skip the first iteration of the loop,
    // because in theory, we would have to access "the dimension of index -1", which would have to be equal to one,
    // but here in code it's just an out-of-bounds access. So we simulate it here, which simplifies the loop,
    // and saves us a bunch of conditionals.
    var space_divisor: T = dimensions[0];
    out[0] = @mod(index, dimensions[0]);
    
    var idx: usize = 1;
    while (idx < dimensions.len) : (idx += 1) {
        out[idx] = @mod(@divTrunc(index, space_divisor), dimensions[idx]);
        space_divisor *= dimensions[idx];
    }
    
}
