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
