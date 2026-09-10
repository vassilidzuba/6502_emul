// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const mem = @import("./memory.zig");

// opcodes

pub const Status = enum(u8) {
    carry = 0,
    zero = 1,
    interrupt = 2,
    decimal = 3,
    breakk = 4,
    ignored = 5,
    overflow = 6,
    negative = 7
    };

pub const FLAG_NEGATIVE  = 0b10000000;
pub const FLAG_OVERFLOW  = 0b01000000;
pub const FLAG_IGNORED   = 0b00100000;
pub const FLAG_BREAK     = 0b00010000;
pub const FLAG_DECIMAL   = 0b00001000;
pub const FLAG_INTERRUPT = 0b00000100;
pub const FLAG_ZERO      = 0b00000010;
pub const FLAG_CARRY     = 0b00000001;

pub const Processor = struct {
    allocator: std.mem.Allocator,
    mem: mem.Memory,
    pc: u16,
    ac: u8,
    x: u8,
    y: u8,
    sr: u8,
    sp: u8,

    pub fn deinit(self: *Processor) void {
        self.mem.deinit();
    }

    pub fn reset(self: *Processor) void {
        self.pc = 0xCD00;
        self.ac = 0;
        self.x = 0;
        self.y = 0;
        self.sr = 0;
        self.sp = 0;
        self.mem.reset();

    }

    pub fn show(self: *Processor) !void {
        var srbuf2 : [256]u8 = undefined;
        var srbuf = srbuf2[0..];
        @memset(srbuf, 0);
        var pos : usize = 0;
        if (self.sr & 0b10000000 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " NEGATIVE");
            pos = pos + 9;
        }
        if (self.sr & 0b01000000 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " OVERFLOW");
            pos = pos + 9;
        }
        if (self.sr & 0b00100000 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " IGNORED");
            pos = pos + 8;
        }
        if (self.sr & 0b00010000 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " BREAK");
            pos = pos + 6;
        }
        if (self.sr & 0b00001000 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " DECIMAL");
            pos = pos + 8;
        }
        if (self.sr & 0b00000100 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " INTERRUPT");
            pos = pos + 10;
        }
        if (self.sr & 0b00000010 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " ZERO");
            pos = pos + 6;
        }
        if (self.sr & 0b00000001 != 0) {
            std.mem.copyForwards(u8, srbuf[pos..], " CARRY");
            pos = pos + 7;
        }


        std.log.info("---------------------------------------------", .{});
        std.log.info("processor:", .{});
        std.log.info("   pc: 0x{X:0>4}", .{self.pc});
        std.log.info("   ac: 0x{X:0>2}  x: 0x{X:0>2}  y: 0x{X:0>2}", .{self.ac, self.x, self.y});
        std.log.info("   sr: {b:0>8} {s}", .{self.sr, srbuf});
        std.log.info("   sp: 0x{X:0>2}", .{self.sp});

        //std.debug.print("pc0 : [u}\n", .{self.pc});
        try self.mem.show();
    }

     inline fn getFlag(self: *Processor, flag: u8) bool {
        return (flag & self.sr) != 0;
    }

    pub inline fn setFlag(self: *Processor, flag: u8, val: bool) void {
        if (val) {
            self.sr = self.sr | flag;
        } else {
            self.sr = self.sr & ~ flag;
        }
    }

    pub inline fn getZeroFlag(self: *Processor) bool {
        return getFlag(self, FLAG_ZERO);
    }

    pub inline fn setZeroFlag(self: *Processor, val: bool) void {
        setFlag(self, FLAG_ZERO, val);
    }

    pub inline fn getNegativeFlag(self: *Processor) bool {
        return getFlag(self, FLAG_NEGATIVE);
    }

    pub inline fn setNegativeFlag(self: *Processor, val: bool) void {
        setFlag(self, FLAG_NEGATIVE, val);
    }

    pub inline fn getCarryFlag(self: *Processor) bool {
        return getFlag(self, FLAG_CARRY);
    }

    pub inline fn setCarryFlag(self: *Processor, val: bool) void {
        setFlag(self, FLAG_CARRY, val);
    }
};

pub fn initProcessor(allocator: std.mem.Allocator, memsize: u16) !Processor {
    var proc: Processor = undefined;
    proc.allocator = allocator;
    proc.mem = try mem.initMemory(allocator, memsize);

    proc.reset();

    return proc;
}
