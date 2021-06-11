const std = @import("std");
const builtin = @import("builtin");
pub const c = @cImport({
    @cInclude("SDL.h");
    @cInclude("SDL_image.h");
});



pub const ErrorSet = error {
    cantInitSubsystems,
    cantCreateWindow,
    cantCreateRenderer,
    
    cantSetBrightness,
    cantSetFullscreen,
    cantSetOpacity,
    
    cantSetRenderColor,
    cantClearRenderer,
    cantRenderLine,
    cantRenderPoint,
    cantRenderRect,
    cantRenderTexture,
    
    cantSetTextureAlphaMod,
    cantSetTextureColorMod,
};

pub const Subsystems = struct {
    timer:          bool = false,
    audio:          bool = false,
    video:          bool = false,
    joystick:       bool = false,
    haptic:         bool = false,
    gamecontroller: bool = false,
    events:         bool = false,
    sensor:         bool = false,
    @"8":            void = {},
    everything:     bool = false,
};

pub const ImgSubsystems = img_subsystems: {
    var out: std.builtin.TypeInfo.Struct = undefined;
    
    out.layout = .Auto;
    out.decls = &[_]std.builtin.TypeInfo.Declaration{};
    out.is_tuple = false;
    
    const raw_enum_fields = @typeInfo(c.IMG_InitFlags).Enum.fields;
    var out_fields: [raw_enum_fields.len]std.builtin.TypeInfo.StructField = undefined;
    inline for (raw_enum_fields) |enum_field, i| {
        out_fields[i].name = new_name_blk: {
            var new_name: [enum_field.name.len]u8 = undefined;
            
            std.mem.copy(u8, &new_name, enum_field.name);
            for (new_name) |*char| char.* = std.ascii.toLower(char.*);
            
            break :new_name_blk new_name[9..];
        };
        out_fields[i].field_type = bool;
        out_fields[i].default_value = false;
        out_fields[i].is_comptime = false;
        out_fields[i].alignment = @alignOf(bool);
    }
    
    out.fields = &out_fields;
    
    break :img_subsystems @Type(.{ .Struct = out });
};

pub fn init(subsystems: Subsystems, img_subsystems: ImgSubsystems) ErrorSet!void {
    
    const flagmask: u32 = blk: {
        var out: u32 = 0;
        inline for(@typeInfo(Subsystems).Struct.fields) |field, i| {
            const value = @field(subsystems, field.name);
            if ( (bool == field.field_type) and (i <= 9) ) {
                out |= @as(u32, @boolToInt(value)) << i;
            }
        }
        
        break:blk out;
    };
    
    const img_flagmask: c_int = blk: {
        var out: c_int = 0;
        inline for (@typeInfo(ImgSubsystems).Struct.fields) |field, i| {
            const value = @field(img_subsystems, field.name);
            if ( (bool == field.field_type) and (i <= 3) ) {
                out |= @as(c_int, @boolToInt(value)) << i;
            }
        }
        break :blk out;
    };
    
    if (c.SDL_Init(flagmask) != 0) {
        return ErrorSet.cantInitSubsystems;
    }
    
    if (c.IMG_Init(img_flagmask) & img_flagmask != img_flagmask) {
        return ErrorSet.cantInitSubsystems;
    }
    
    
    
}

pub fn deinit() callconv(.Inline) void {
    return c.SDL_Quit();
}

/// Created by invoking Window.init
/// Deinitialized by invoking Window.deinit
pub const Window = struct {
    handle: *c.SDL_Window,
    
    const Self = @This();
    
    pub fn init(args: Ctr) !Self {
        
        const flagmask: u32 = blk: {
            var out: u32 = 0;
            inline for(@typeInfo(Ctr).Struct.fields) |field, i| {
                
                const value = @field(args, field.name);
                if (field.field_type == bool and i <= 21) {
                    out |= @as(u32, @boolToInt(value)) << i;
                }
                
            }
            
            break :blk out;
        };
        
        return if (c.SDL_CreateWindow(@ptrCast([*]const u8, args.title), args.x, args.y, args.w, args.h, flagmask))
        |ptr| Self{ .handle = ptr } else ErrorSet.cantCreateWindow;
        
    }
    
    pub fn deinit(self: Self) callconv(.Inline) void {
        return c.SDL_DestroyWindow(self.handle);
    }
    
    pub fn createRenderer(self: Self, args: Renderer.Ctr) !Renderer {
        
        const flagmask: u32 = blk: {
            var out: u32 = 0;
            inline for(@typeInfo(Renderer.Ctr).Struct.fields) |field, i| {
                
                const value = @field(args, field.name);
                if (field.field_type == bool and i <= 3) {
                    out |= @as(u32, @boolToInt(value)) << i;
                }
                
            }
            
            break :blk out;
        };
        
        return if (c.SDL_CreateRenderer(self.handle, args.index, flagmask))
        |ptr| Renderer{ .handle = ptr } else ErrorSet.cantCreateRenderer;
        
    }
    
    pub fn getGrabbed() callconv(.Inline) ?Self {
        return if(c.SDL_GetGrabbedWindow())
        |ptr| Self{ .handle = ptr } else null;
    }
    
    pub fn getBordersSize(self: Self) ?BordersSize {
        var out: BordersSize = undefined;
        return if (c.SDL_GetWindowBordersSize(&out.top, &out.left, &out.bottom, &out.right) == 0)
        out else null;
    }
    
    pub fn getBrightness(self: Self) callconv(.Inline) f32 {
        return c.SDL_GetWindowBrightness(self.handle);
    }
    
    // Omitted: SDL_GetWindowData
    
    // Omitted: SDL_GetWindowDisplayIndex
    
    // Omitted: SDL_GetWindowDisplayMode
    
    // Omitted: SDL_GetWindowFlags
    
    pub fn fromID(id: u32) callconv(.Inline) ?Self {
        return if (c.SDL_GetWindowFromID(id))
        |ptr| Self{ .handle = ptr } else null;
    }
    
    // Omitted: SDL_GetWindowGammaRamp
    
    pub fn getGrab(self: Self) callconv(.Inline) bool {
        return (c.SDL_GetWindowGrab(self.handle)) != 0;
    }
    
    pub fn getID(self: Self) ?u32 {
        const out = c.SDL_GetWindowID(self.handle);
        return if (out == 0)
        out else null;
    }
    
    pub fn getMaxSize(self: Self) Size {
        var out: Size(.i) = undefined;
        c.SDL_GetWindowMaximumSize(self.handle, &out.w, &out.h);
        return out;
    }
    
    pub fn getMinSize(self: Self) Size {
        var out: Size(.i) = undefined;
        c.SDL_GetWindowMinimumSize(self.handle, &out.w, &out.h);
        return out;
    }
    
    pub fn getOpacity(self: Self) ?f32 {
        var out = undefined;
        const exit_code = c.SDL_GetWindowOpacity(self.handle, &out);
        return if (exit_code == 0)
        out else null;
    }
    
    // Omitted: SDL_GetWindowPixelFormat
    
    pub fn getPosition(self: Self) Point(.i) {
        var out: Point(.i) = undefined;
        c.SDL_GetWindowPosition(self.handle, &out.x, &out.y);
        return out;
    }
    
    pub fn getSize(self: Self) Size(.i) {
        var out: Size(.i) = undefined;
        c.SDL_GetWindowSize(self.handle, &out.w, &out.h);
        return out;
    }
    
    // Omitted: SDL_GetWindowSurface
    
    pub fn getTitle(self: Self) callconv(.Inline) []const u8 {
        return c.SDL_GetWindowTitle(self.handle);
    }
    
    // Omitted: SDL_GetWindowWMInfo
    
    // Omitted: SDL_GL_CreateContext
    
    // Omitted: SDL_GL_DeleteContext
    
    // Omitted: SDL_GL_GetCurrentWindow
    
    // Omitted: SDL_GL_GetDrawableSize
    
    // Omitted: SDL_GL_MakeCurrent
    
    // Omitted: SDL_GL_SwapWindow
    
    pub fn hide(self: Self) callconv(.Inline) void {
        return c.SDL_HideWindow(self.handle);
    }
    
    pub fn maximize(self: Self) callconv(.Inline) void {
        return c.SDL_MaximizeWindow(self.handle);
    }
    
    pub fn minimize(self: Self) callconv(.Inline) void {
        return c.SDL_MinimizeWindow(self.handle);
    }
    
    pub fn raise(self: Self) callconv(.Inline) void {
        return c.SDL_RaiseWindow(self.handle);
    }
    
    pub fn restore(self: Self) callconv(.Inline) void {
        return c.SDL_RestoreWindow(self.handle);
    }
    
    
    
    pub fn setBordered(self: Self, on: bool) callconv(.Inline) void {
        return c.SDL_SetWindowBordered(self.handle, @boolToInt(on));
    }
    
    pub fn setBrightness(self: Self, brightness: f32) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetWindowBrightness(self.handle, brightness) == 0)
        {} else ErrorSet.cantSetBrightness;
    }
    
    // Omitted: SDL_SetWindowData
    
    // Omitted: SDL_SetWindowDisplayMode
    
    pub fn setWindowFullscreen(self: Self, mode: Fullscreen) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetWindowFullscreen(self.handle, mode) == 0)
        {} else ErrorSet.cantSetFullscreen;
    }
    
    // Omitted: SDL_SetWindowGammaRamp
    
    pub fn setGrab(self: Self, on: bool) callconv(.Inline) void {
        return c.SDL_SetWindowGrab(self.handle, @boolToInt(on));
    }
    
    // Omitted: SDL_SetWindowHitTest
    
    // Omitted: SDL_SetWindowIcon
    
    // Omitted: SDL_SetWindowInputFocus
    
    pub fn setMaxSize(self: Self, size: Size(.i)) callconv(.Inline) void {
        return c.SDL_SetWindowMaximumSize(self.handle, size.w, size.h);
    }
    
    pub fn setMinSize(self: Self, size: Size(.i)) callconv(.Inline) void {
        return c.SDL_SetWindowMinimumSize(self.handle, size.w, size.h);
    }
    
    // Omitted: SDL_SetWindowModalFor
    
    pub fn setOpacity(self: Self, opacity: f32) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetWindowOpacity(self.handle, opacity) == 0)
        {} else ErrorSet.cantSetOpacity;
    }
    
    pub fn setPosition(self: Self, pos: Point(.i)) callconv(.Inline) void {
        return c.SDL_SetWindowPosition(self.handle, pos.x, pos.y);
    }
    
    pub fn setTitle(self: Self, title: []const u8) callconv(.Inline) void {
        return c.SDL_SetWindowTitle(self.handle, @ptrCast([*]const u8, title));
    }
    
    
    
    pub fn show(self: Self) callconv(.Inline) void {
        return c.SDL_ShowWindow(self.handle);
    }
    
    // Omitted: SDL_UpdateWindowSurface
    
    // Omitted: SDL_UpdateWindowSurfaceRects
    
    pub fn warpMouse(self: Self, pos: Point(.i)) callconv(.Inline) void {
        return c.SDL_WarpMouseInWindow(pos.x, pos.y);
    }
    
    pub fn getRenderer(self: Self) callconv(.Inline) ?Renderer {
        return if(c.SDL_GetRenderer(self.handle))
        |ptr| Renderer{ .handle = ptr } else null;
    }
    
    pub const Fullscreen = enum(u32) {
        Off = 0,
        Normal = c.SDL_WINDOW_FULLSCREEN,
        Desktop = c.SDL_WINDOW_FULLSCREEN_DESKTOP,
    };
    
    pub const BordersSize = struct {
        top: c_int,
        left: c_int,
        bottom: c_int,
        right: c_int,
    };
    
    pub const Ctr = struct {
        fullscreen: bool = false,
        opengl: bool = false,
        @"2": void = {},
        hidden: bool = false,
        borderless: bool = false,
        resizable: bool = false,
        minimized: bool = false,
        maximized: bool = false,
        input_grabbed: bool = false,
        @"9": void = {},
        @"10": void = {},
        fullscreen_desktop: bool = false,
        @"12": void = {},
        allow_highdpi: bool = false,
        @"14": void = {},
        @"15": void = {},
        @"16": void = {},
        @"17": void = {},
        @"18": void = {},
        @"19": void = {},
        vulkan: bool = false,
        metal: bool = false,
        
        title: []const u8 = "",
        x: c_int = c.SDL_WINDOWPOS_UNDEFINED,
        y: c_int = c.SDL_WINDOWPOS_UNDEFINED,
        w: c_int,
        h: c_int,
    };
    
};

/// Created by invoking Window.createRenderer
/// Deinitialized by invoking Renderer.deinit
pub const Renderer = struct {
    handle: *c.SDL_Renderer,
    
    const Self = @This();
    
    pub fn deinit(self: Self) callconv(.Inline) void {
        return c.SDL_DestroyRenderer(self.handle);
    }
    
    // Omitted: SDL_CreateSoftwareRenderer
    
    // Omitted: SDL_GetRenderDrawBlendMode
    
    pub fn getDrawColor(self: Self) ?Color {
        var out: Color = undefined;
        return if(SDL_GetRenderDrawColor(self.handle, &out.r, &out.g, &out.b, &out.a) == 0)
        out else null;
    }
    
    // Omitted: SDL_GetRenderDriverInfo
    
    // In Window Struct: SDL_GetRenderer
    
    // Omitted: SDL_GetRendererInfo
    
    pub fn getOutputSize(self: Self) ?Size(.i) {
        var out: Size(.i) = undefined;
        return if (c.SDL_GetRendererOutputSize(self.handle, &out.w, &out.h) == 0)
        out else null;
    }
    
    // Omitted: SDL_GetRenderTarget
    
    pub fn drawClear(self: Self) callconv(.Inline) ErrorSet!void {
        return if(c.SDL_RenderClear(self.handle) == 0)
        {} else ErrorSet.cantClearRenderer;
    }
    
    pub fn drawTexture(self: Self, comptime A: Arithmetic, texture: Texture, src: ?Rect(.i), dst: ?Rect(A)) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderCopy
        else if (A == .f) c.SDL_RenderCopyF;
        
        return if (func(
            self.handle,
            texture.handle,
            if(src) |*r| @ptrCast(*const CRect(.i), r) else null,
            if(dst) |*r| @ptrCast(*const CRect(A), r) else null,
        ) == 0)
        {} else ErrorSet.cantRenderTexture;
        
    }
    
    pub fn drawTextureEx(self: Self, comptime A: Arithmetic, texture: Texture, src: ?Rect(.i), dst: ?Rect(A), center: ?Point(A), angle: f64, flip_mode: TextureFlipMode) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderCopyEx
        else if (A == .f) c.SDL_RenderCopyExF;
        
        return if(func(
            self.handle,
            texture.handle,
            if(src)|*r| @ptrCast(*const CRect(.i), r) else null,
            if(dst) |*r| @ptrCast(*const CRect(A), r) else null,
            angle,
            if(center) |*p| @ptrCast(*const CPoint(A), p) else null,
            @intToEnum(c.SDL_RendererFlip, @enumToInt(flip_mode)),
        ) == 0)
        {} else ErrorSet.cantRenderTexture;
        
    }
    
    pub fn drawLine(self: Self, comptime A: Arithmetic, p1: Point(A), p2: Point(A)) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderDrawLine
        else if (A == .f) c.SDL_RenderDrawLineF
        else              unreachable;
        
        return if (func(self.handle, p1.x, p1.y, p2.x, p2.y) == 0)
        {} else ErrorSet.cantRenderLine;
        
    }
    
    pub fn drawLines(self: Self, comptime A: Arithmetic, points: []const Point(A)) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderDrawLines
        else if (A == .f) c.SDL_RenderDrawLinesF
        else              unreachable;
        
        return if (func(self.handle, @ptrCast([*]const CPoint(A), points), @intCast(c_int, points.len)) == 0)
        {} else ErrorSet.cantRenderLine;
        
    }
    
    pub fn drawPoint(self: Self, comptime A: Arithmetic, point: Point(A)) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderDrawPoint
        else if (A == .f) c.SDL_RenderDrawPointF
        else              unreachable;
        
        return if(func(self.handle, point.x, point.y) == 0)
        {} else ErrorSet.cantRenderPoint;
        
    }
    
    pub  fn drawPoints(self: Self, comptime A: Arithmetic, points: []const Point(A)) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i) c.SDL_RenderDrawPoints
        else if (A == .f) c.SDL_RenderDrawPointsF
        else              unreachable;
        
        return if (func(self.handle, @ptrCast([*]const CPoint(A), points), @intCast(c_int, points.len)) == 0)
        {} else ErrorSet.cantRenderPoint;
        
    }
    
    pub fn drawRect(self: Self, comptime A: Arithmetic, rect: Rect(A), comptime mode: RectDrawMode) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i and mode == .Empty) c.SDL_RenderDrawRect
        else if (A == .f and mode == .Empty) c.SDL_RenderDrawPointF
        else if (A == .i)                    c.SDL_RenderFillRect
        else if (A == .f)                    c.SDL_renderFillRectF
        else                                 unreachable;
        
        return if (func(self.handle, rect.cPtr()) == 0)
        {} else ErrorSet.cantRenderRect;
        
    }
    
    pub fn drawRects(self: Self, comptime A: Arithmetic, rects: []const Rect(A), comptime mode: RectDrawMode) callconv(.Inline) ErrorSet!void {
        
        const func
        =    if (A == .i and mode == .Empty) c.SDL_RenderDrawRects
        else if (A == .f and mode == .Empty) c.SDL_RenderDrawPointsF
        else if (A == .i)                    c.SDL_RenderFillRects
        else if (A == .f)                    c.SDL_renderFillRectsF
        else                                 unreachable;
        
        return if(func(self.handle, @ptrCast([*]const CRect(A), rects.ptr), @intCast(c_int, rects.len)) == 0)
        {} else ErrorSet.cantRenderRect;
        
    }
    
    // Omitted: SDL_RenderGetClipRect
    // Omitted: SDL_RenderGetD3D9Device
    // Omitted: SDL_RenderGetIntegerScale
    // Omitted: SDL_RenderGetLogicalSize
    // Omitted: SDL_RenderGetScale
    // Omitted: SDL_RenderGetViewport
    // Omitted: SDL_RenderIsClipEnabled
    
    pub fn drawUpdate(self: Self) callconv(.Inline) void {
        return c.SDL_RenderPresent(self.handle);
    }
    
    // Omitted: SDL_RenderReadPixels
    // Omitted: SDL_RenderSetClipRect
    // Omitted: SDL_RenderSetIntegerScale
    // Omitted: SDL_RenderSetLogicalSize
    // Omitted: SDL_RenderSetScale
    // Omitted: SDL_RenderSetViewport
    // Omitted: SDL_RenderTargetSupported
    // Omitted: SDL_SetRenderDrawBlendMode
    
    pub fn drawColor(self: Self, color: Color) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetRenderDrawColor(self.handle, color.r, color.g, color.b, color.a) == 0)
        {} else ErrorSet.cantSetRenderColor;
    }
    
    // Omitted: SDL_SetRenderTarget
    
    pub fn createTexture(self: Self, arg: union(enum) { path: []const u8, surface: Surface }) callconv(.Inline) ?Texture {
        return switch(arg) {
            .path => |p| if (c.IMG_LoadTexture(self.handle, @ptrCast([*]const u8, p))) |ptr| Texture{ .handle = ptr } else null,
            .surface => |s| if (c.SDL_CreateTextureFromSurface(self.handle, s.handle)) |ptr| Texture{ .handle = ptr } else null,
        };
    }
    
    pub const TextureFlipMode = enum(@typeInfo(c.SDL_RendererFlip).Enum.tag_type) {
        None = 0,
        Horizontal  = 1,
        Vertical    = 2,
        Both        = 1 | 2
    };
    
    pub const RectDrawMode = enum {
        Empty,
        Full,
        
        pub fn isEq(self: Cell, to: Cell) bool {
            return self == to;
        }
        
        pub fn isEmpty(self: Cell) bool {
            return self.isEq(.Empty);
        }
        
        pub fn isFull(self: Cell) bool {
            return self.isEq(.Full);
        }
    };
    
    pub const Ctr = struct {
        software: bool = false,
        accelerated: bool = false,
        presentvsync: bool = false,
        targettexture: bool = false,
        
        index: c_int = -1,
        
    };
    
};

/// Default constructible.
/// Invoke Event.poll to poll events and get the polled event type.
/// Most useful in a while loop paired with a switch case.
/// e.g. while(Event{}.poll()) |event_type| switch(event_type) {...}.
pub const Event = struct {
    const CEvent = c.SDL_Event;
    
    data: CEvent = undefined,
    
    /// Polls event queue. If an event is pending, a Event.PollPayload is returned,
    /// where 'id' is the type of event, and 'data' is a pointer to the raw C union with the corresponding event data.
    /// Otherwise, returns null.
    pub fn poll(self: *@This()) callconv(.Inline) ?PollPayload {
        return if (c.SDL_PollEvent(&self.data) != 0)
        .{.id = @intToEnum(Type, @intCast(c_int, self.data.@"type")), .data = &self.data } else null;
    }
    
    pub const PollPayload = struct { id: Type, data: *CEvent };
    
    /// Enum generated from, and based off of SDL_EventType (in 'c').
    /// All fields are un-prefixed and lowercase'd versions of the ones in SDL_EventType.
    /// e.g. 'SDL_QUIT' becomes 'quit', retaining the same value (256).
    pub const Type = type_info_blk: {
        var enum_info: std.builtin.TypeInfo.Enum = undefined;
        const raw_enum_info = @typeInfo(c.SDL_EventType).Enum;
        
        enum_info.layout = .Auto;
        enum_info.tag_type = raw_enum_info.tag_type;
        enum_info.decls = &[_]std.builtin.TypeInfo.Declaration{};
        enum_info.is_exhaustive = true;
        
        enum_info.fields = fields_blk: {
            
            // Output array of Enum Fields.
            var out: [(raw_enum_info.fields.len)]std.builtin.TypeInfo.EnumField = undefined;
            
            inline for(raw_enum_info.fields) |field, i| {
                @setEvalBranchQuota(2000); // Needs a minimum of 1821, but for simplicity's sake set to 2000
                
                out[i] = .{
                    .value = field.value,
                    .name = name_blk: {
                        
                        const new_name_upper = field.name[4..]; // Discard the 'SDL_' prefix
                        
                        var name_out: [new_name_upper.len]u8 = undefined; // Buffer for the new name all lowercase.
                        
                        inline for(new_name_upper) |char, name_idx| {
                            // Iterate over each character in 'new_name_upper', and convert it to lowercase, turning QUIT to quit in the buffer.
                            name_out[name_idx] = std.ascii.toLower(char);
                        }
                        
                        break:name_blk name_out[0..]; // Return comptime slice.
                        
                    },
                };
                
            }
            
            break:fields_blk out[0..]; // Return comptime slice
            
        };
        
        break:type_info_blk @Type(.{ .Enum = enum_info }); // Return retified type.
        
    };
    
    /// TODO: Make public once they fix the issue of making a union from a @typeInfo with an enum tag.
    const Data = comptime type_info_blk: {
        const raw_union_info = @typeInfo(c.SDL_Event).Union;
        
        const DataEnum = @Type(.{ .Enum = .{
            .layout = .Auto,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .tag_type = c_int,
            .is_exhaustive = true,
            .fields = union_info_fields_blk: {
                
                var enum_info_fields_out: [raw_union_info.fields.len]std.builtin.TypeInfo.EnumField = undefined;
                for (raw_union_info.fields) |union_field, idx| {
                    
                    enum_info_fields_out[idx].name = union_field.name;
                    enum_info_fields_out[idx].value = idx;
                    
                } break :union_info_fields_blk &enum_info_fields_out;
                
            },
        }});
        
        const union_info: std.builtin.TypeInfo.Union = .{
            .layout = .Auto,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .tag_type = DataEnum,
            .fields = union_info_fields_blk: {
                
                var union_info_fields_out: [(raw_union_info.fields.len)]std.builtin.TypeInfo.UnionField = undefined;
                for (raw_union_info.fields) |union_field, idx| {
                    
                    union_info_fields_out[idx].field_type = union_field.field_type;
                    union_info_fields_out[idx].alignment = @alignOf(union_field.field_type);
                    union_info_fields_out[idx].name = union_field.name;
                    
                } break :union_info_fields_blk &union_info_fields_out;
                
            },
            
        };
        
        break :type_info_blk @Type(.{ .Union = union_info });
    };
    
};



/// Created by invoking Renderer.createTexture
/// Deinitialized by invoking Texture.deinit
pub const Texture = struct {
    handle: *c.SDL_Texture,
    
    const Self = @This();
    
    pub fn deinit(self: Self) callconv(.Inline) void {
        return c.SDL_DestroyTexture(self.handle);
    }
    
    pub fn getAlphaMod(self: Self) ?u8 {
        var out: u8 = undefined;
        if (c.SDL_GetTextureAlphaMod(self.handle, &out) == 0)
        out else null;
    }
    
    // Omitted: SDL_GetTextureBlendMode
    
    pub fn getColorMod(self: Self) ?Color {
        var out: Color = undefined;
        return if (c.SDL_GetTextureColorMod(self.handle, &out.r, &out.g, &out.b) == 0)
        out else null;
    }
    
    // Omitted: SDL_LockTexture
    
    // Omitted: SDL_QueryTexture
    
    pub fn setAlphaMod(self: Self, alpha: u8) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetTextureAlphaMod(self.handle, alpha) == 0)
        {} else ErrorSet.cantSetTextureAlphaMod;
    }
    
    // Omitted: SDL_SetTextureBlendMode
    
    pub fn setColorMod(self: Self, rgb: struct { r: u8 = 255, g: u8 = 255, b: u8 = 255 }) callconv(.Inline) ErrorSet!void {
        return if (c.SDL_SetTextureColorMod(self.handle, rgb.r, rgb.g, rgb.b) == 0)
        {} else ErrorSet.cantSetTextureColorMod;
    }
    
    // Omitted: SDL_UnlockTexture
    
    // Omitted: SDL_UpdateTexture
    
    // Omitted: SDL_UpdateYUVTexture
    
};

pub const Surface = struct {
    handle: *c.SDL_Surface,
};



pub const Arithmetic = enum {
    i, // Integer
    f  // Float
};

pub fn CArithmetic(comptime A: Arithmetic) type {
    return switch(A) {
        .i => c_int,
        .f => f32,
    };
}



pub fn CPoint(comptime A: Arithmetic) type {
    return switch(A) {
        .i => c.SDL_Point,
        .f => c.SDL_FPoint,
    };
}

pub fn Point(comptime A: Arithmetic) type {
    const T = CArithmetic(A);
    return extern struct {
        x: T = 0,
        y: T = 0,
        
        const Self = @This();
        
        pub fn cPtr(self: *const Self) *const CPoint(A) {
            return @ptrCast(*const CPoint(A), self);
        }
        
    };
}



pub fn CRect(comptime A: Arithmetic) type {
    return switch(A) {
        .i => c.SDL_Rect,
        .f => c.SDL_FRect,
    };
}

pub fn Rect(comptime A: Arithmetic) type {
    const T = CArithmetic(A);
    return extern struct {
        x: T = 0, y: T = 0,
        w: T = 0, h: T = 0,
        
        const Self = @This();
        
        pub fn cPtr(self: *const Self) *const CRect(A) {
            return @ptrCast(*const CRect(A), self);
        }
        
    };
}



pub fn Size(comptime A: Arithmetic) type {
    const T = CArithmetic(A);
    return struct {
        w: T, h: T,
        
        const Self = @This();
        
        pub fn point(self: Self) Point(A) {
            return .{ .x = self.w, .y = self.h };
        }
        
        pub fn rect(self: Self) Rect(A) {
            return .{ .w = self.w, .h = self.h };
        }
        
    };
}



pub const CColor = c.SDL_Color;

pub const Color = extern struct {
    r: u8 = 255,
    g: u8 = 255,
    b: u8 = 255,
    a: u8 = 255,
    
    const Self = @This();
    
    pub fn cPtr(self: *const Color) *const CColor {
        return @ptrCast(*const CColor, self);
    }
    
    pub const white   = Self{ .r = 255, .g = 255, .b = 255 };
    pub const black   = Self{ .r = 0,   .g = 0,   .b = 0   };
    
    pub const red     = Self{ .r = 255, .g = 0,   .b = 0   };
    pub const green   = Self{ .r = 0,   .g = 255, .b = 0   };
    pub const blue    = Self{ .r = 0,   .g = 0,   .b = 255 };
    
    pub const cyan    = Self{ .r = 0,   .g = 255, .b = 255 };
    pub const magenta = Self{ .r = 255, .g = 0,   .b = 255 };
    pub const yellow  = Self{ .r = 255, .g = 255, .b = 0   };
    
};

pub const Mouse = struct {
    x: c_int,
    y: c_int,
    left: bool,
    middle: bool,
    right: bool,
    
    pub fn get(comptime T: Type) Mouse {
        
        const func = switch(T) {
            .Relative => c.SDL_GetMouseState,
            .Global => c.SDL_GetGlobalMouseState,
        };
        
        var x: c_int = 0;
        var y: c_int = 0;
        
        const mask = func(&x, &y);
        const left   = (mask & c.SDL_BUTTON_LMASK) != 0;
        const middle = (mask & c.SDL_BUTTON_MMASK) != 0;
        const right  = (mask & c.SDL_BUTTON_RMASK) != 0;
        
        return Mouse {
            .x = x,
            .y = y,
            .left = left,
            .middle = middle,
            .right = right,
        };
        
    }
    
    const Type = enum {
        Relative,
        Global, /// Not necessarily recommended. Might be slower than .Relative, according to the SDL wiki, since it queries the OS.
    };
    
};

pub const Keyboard = struct {
    
    pub fn scanCode(scancode: Scancode) bool {
        const kb = c.SDL_GetKeyboardState(null);
        const sdl_scancode = @enumToInt(scancode);
        return kb[@intCast(usize, sdl_scancode)] != 0;
    }
    
    /// Mirrors the SDL_Scancode enum, except names are all lowercase, and excludes the 'SDL_SCANCODE' prefix.
    /// For any of the number keys, use @"n" to refer to the enum name. This is a limitation of consistency,
    /// and also from the fact that it would be very tricky to actually handle it.
    pub const Scancode = comptime blk: {
        const raw_enum_info = @typeInfo(c.SDL_Scancode).Enum;
        
        var out: std.builtin.TypeInfo = .{ .Enum = .{
            .layout = .Auto,
            .tag_type = raw_enum_info.tag_type,
            .decls = &[_]std.builtin.TypeInfo.Declaration{},
            .fields = &[_]std.builtin.TypeInfo.EnumField{},
            .is_exhaustive = true,
        }};
        
        var new_fields: [raw_enum_info.fields.len]std.builtin.TypeInfo.EnumField = undefined;
        for (raw_enum_info.fields) |field, i| {
            @setEvalBranchQuota(4000);
            new_fields[i] = .{
                .value = field.value,
                .name = name_blk: {
                    const new_name_slice = field.name[13..field.name.len];
                    var name_out: [new_name_slice.len]u8 = new_name_slice.*;
                    for (name_out) |*char| { char.* = std.ascii.toLower(char.*); }
                    break :name_blk &name_out;
                }
            };
        }
        out.Enum.fields = &new_fields;
        
        break :blk @Type(out);
    };
    
};



/// Anything related to building this library.
pub const build = struct {
    
    /// Set up the SDL library on Windows. Use in build.zig
    pub fn setUp(comptime library_directory: []const u8, b: *std.build.Builder, exe: *std.build.LibExeObjStep) void {
        exe.linkLibC();
        
        sdl2_setup: {
            const dir = library_directory ++ "/SDL2-2.0.14/";
            exe.addIncludeDir(dir ++ "include/");
            exe.addLibPath(dir ++ "lib/x64/");
            exe.linkSystemLibrary("SDL2");
            b.installBinFile(dir ++ "lib/x64/SDL2.dll", "SDL2.dll");
            break :sdl2_setup;
        }
        
        sdl2_image_setup: {
            const dir = library_directory ++ "/SDL2_image-2.0.5/";
            exe.addIncludeDir(dir ++ "include/");
            exe.addLibPath(dir ++ "lib/x64/");
            exe.linkSystemLibrary("SDL2_image");
            b.installBinFile(dir ++ "lib/x64/SDL2_image.dll", "SDL2_image.dll");
            
            const dll_files = .{
                "libjpeg-9.dll",
                "libpng16-16.dll",
                "libtiff-5.dll",
                "libwebp-7.dll",
                "zlib1.dll",
            };
            
            inline for (dll_files) |dll| {
                b.installBinFile(dir ++ "lib/x64/" ++ dll, dll);
            }
            
            break :sdl2_image_setup;
        }
    }

};
