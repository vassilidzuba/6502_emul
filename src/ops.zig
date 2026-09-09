// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const proc = @import("./processor.zig");

pub const NUL = 0;
pub const DEC_Z = 0xC6;
pub const DEC_ZX = 0xD6;
pub const DEC_A = 0xCE;
pub const DEC_AX = 0xDE;
pub const DEX_I = 0xCA;
pub const DEY_I = 0x88;
pub const LDA_I = 0xA9;
pub const LDA_Z = 0xA5;
pub const LDA_ZX = 0xB5;
pub const LDA_A = 0xAD;
pub const LDA_AX = 0xBD;
pub const LDA_AY = 0xB9;
pub const LDA_IX = 0xA1;
pub const LDA_IY = 0xB1;
pub const LDX_I = 0xA2;
pub const LDX_Z = 0xA6;
pub const LDY_I = 0xA0;
pub const LDY_Z = 0xA4;
pub const STA_Z = 0x85;
pub const STA_A = 0x8D;
pub const STX_Z = 0x86;
pub const STX_ZY = 0x96;
pub const STX_A = 0x8E;
pub const STY_Z = 0x84;
pub const STY_ZX = 0x94;
pub const STY_A = 0x8C;

pub var opTable: [256]Op = undefined;

fn addOpTable(code: u8, f: fn (*proc.Processor, *i32) void) void {
    opTable[code] = .{ .code = code, .impl = f };
}

pub fn initOpTable() void {
    for (0..256) |ii| {
        addOpTable(@intCast(ii), exec_ILLEG);
    }

    addOpTable(DEC_Z, exec_DEC_Z);
    addOpTable(DEC_ZX, exec_DEC_ZX);
    addOpTable(DEC_A, exec_DEC_A);
    addOpTable(DEC_AX, exec_DEC_AX);
    addOpTable(DEX_I, exec_DEX_I);
    addOpTable(DEY_I, exec_DEY_I);
    addOpTable(LDA_I, exec_LDA_I);
    addOpTable(LDA_Z, exec_LDA_Z);
    addOpTable(LDA_ZX, exec_LDA_ZX);
    addOpTable(LDA_A, exec_LDA_A);
    addOpTable(LDA_AX, exec_LDA_AX);
    addOpTable(LDA_AY, exec_LDA_AY);
    addOpTable(LDA_IX, exec_LDA_IX);
    addOpTable(LDA_IY, exec_LDA_IY);
    addOpTable(LDX_I, exec_LDX_I);
    addOpTable(LDX_Z, exec_LDX_Z);
    addOpTable(LDY_I, exec_LDY_I);
    addOpTable(LDY_Z, exec_LDY_Z);
    addOpTable(STA_Z, exec_STA_Z);
    addOpTable(STA_A, exec_STA_A);
    addOpTable(STX_Z, exec_STX_Z);
    addOpTable(STX_ZY, exec_STX_ZY);
    addOpTable(STX_A, exec_STX_A);
    addOpTable(STY_Z, exec_STY_Z);
    addOpTable(STY_ZX, exec_STY_ZX);
    addOpTable(STY_A, exec_STY_A);
}

pub const Op = struct {
    code: u8,
    impl: *const fn (p: *proc.Processor, cy: *i32) void,

    pub fn exec(self: *const Op, p: *proc.Processor, cy: *i32) void {
        self.impl(p, cy);
    }
};

fn getZeropageAddress(p: *proc.Processor) usize {
    const adr = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    return adr;
}

fn getZeropageXAddress(p: *proc.Processor) usize {
    const adr1 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    const adr2: u16 = adr1;
    var adr = adr2 + p.x;
    adr = adr & 0x00FF;
    return adr;
}

fn getZeropageYAddress(p: *proc.Processor) usize {
    const adr1 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    const adr2: u16 = adr1;
    var adr = adr2 + p.y;
    adr = adr & 0x00FF;
    return adr;
}

fn getAbsoluteAddress(p: *proc.Processor) usize {
    const adr1: u16 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    const adr2: u16 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    var adr: u16 = adr2;
    adr = adr2 * 256 + adr1;
    return adr;
}

fn getAbsoluteXAddress(p: *proc.Processor) usize {
    const adr = getAbsoluteAddress(p);
    return adr + p.y;
}

fn getAbsoluteYAddress(p: *proc.Processor) usize {
    const adr = getAbsoluteAddress(p);
    return adr + p.y;
}

fn getIndirectXAddress(p: *proc.Processor) usize {
    var zadr: u16 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    zadr = (zadr + p.x) & 0x00FF;
    const adr1: u16 = p.mem.mem[zadr];
    const adr2: u16 = p.mem.mem[zadr + 1];
    const adr = adr2 * 256 + adr1;
    return adr;
}

fn getIndirectYAddress(p: *proc.Processor) usize {
    const zadr: u16 = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    const adr1: u16 = p.mem.mem[zadr];
    const adr2: u16 = p.mem.mem[zadr + 1];
    const adr = adr2 * 256 + adr1 + p.y;
    return adr;
}

fn exec_ILLEG(p: *proc.Processor, cy: *i32) void {
    std.log.info("illegal opcode {X:0>2} (cycle {d})", .{ p.mem.mem[p.pc], cy.* });
    cy.* = -1024;
}

fn exec_DEC(p: *proc.Processor, adr: usize) void {
    var val: u16 = p.mem.mem[adr];
    if (val == 0) {
        val = 255;
    } else {
        val = val - 1;
    }
    p.mem.mem[adr] = @intCast(val);
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
}

fn exec_DEC_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEC_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_DEC_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEC_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_DEC_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEC_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_DEC_AX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEC_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_DEX_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEX_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    var val : u16 = p.x;
    if (val == 0) {
        val = 0xFF;
    } else {
        val = val - 1;
    }
    p.x = @intCast(val);
    cy.* = cy.* - 2;
}

fn exec_DEY_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEY_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    var val : u16 = p.y;
    if (val == 0) {
        val = 0xFF;
    } else {
        val = val - 1;
    }
    p.y = @intCast(val);
    cy.* = cy.* - 2;
}

fn exec_LDA_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const val = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_LDA_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_LDA_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDA_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    std.log.info("adr = {X}", .{adr});
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDA_AX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_AX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);
    std.log.info("adr = {X}", .{adr});
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDA_AY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_AY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteYAddress(p);
    std.log.info("adr = {X}", .{adr});
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDA_IX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_IX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectXAddress(p);
    std.log.info("adr = {X}", .{adr});
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDA_IY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDA_IY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectYAddress(p);
    std.log.info("adr = {X}", .{adr});
    const val = p.mem.mem[adr];
    p.ac = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 4;
}

fn exec_LDX_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDX_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const val = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    p.x = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_LDX_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDX_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    const val = p.mem.mem[adr];
    p.x = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_LDY_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDY_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const val = p.mem.mem[p.pc];
    p.pc = p.pc + 1;
    p.y = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_LDY_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running LDY_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    const val = p.mem.mem[adr];
    p.y = val;
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
    cy.* = cy.* - 2;
}

fn exec_STA_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STA_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    p.mem.mem[adr] = p.ac;
    cy.* = cy.* - 3;
}

fn exec_STA_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STA_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    p.mem.mem[adr] = p.ac;
    cy.* = cy.* - 4;
}

fn exec_STX_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STX_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    p.mem.mem[adr] = p.x;
    cy.* = cy.* - 3;
}

fn exec_STX_ZY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STX_ZY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageYAddress(p);
    p.mem.mem[adr] = p.x;
    cy.* = cy.* - 4;
}

fn exec_STX_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STX_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    p.mem.mem[adr] = p.x;
    cy.* = cy.* - 4;
}

fn exec_STY_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STY_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    p.mem.mem[adr] = p.y;
    cy.* = cy.* - 3;
}

fn exec_STY_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STY_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    p.mem.mem[adr] = p.y;
    cy.* = cy.* - 3;
}

fn exec_STY_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running STY_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    p.mem.mem[adr] = p.y;
    cy.* = cy.* - 4;
}

pub fn run(p: *proc.Processor, maxCycles: i32) void {
    var cy = maxCycles;
    while (true) {
        if (cy <= 0) {
            if (cy > -1024) {
                std.log.info("too many cycles", .{});
            }
            return;
        }

        const code = p.mem.mem[p.pc];
        const op = opTable[code];

        op.exec(p, &cy);
    }
}

pub fn setProgram(p: *proc.Processor, program: []const u8) void {
    var pos: usize = 0xCD00;
    for (program) |code| {
        p.mem.mem[pos] = code;
        pos = pos + 1;
    }
}

pub fn setProgramAndRun(p: *proc.Processor, program: []const u8) void {
    setProgram(p, program);
    run(p, 1000);
}

fn runTest(program: []const u8) !proc.Processor {
    const ta = std.testing.allocator;
    var p: proc.Processor = try proc.initProcessor(ta, 64_000);
    initOpTable();
    setProgramAndRun(&p, program);
    return p;
}

test "DEC_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_Z, 0x10, DEC_Z, 0x10, LDA_Z, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x71);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "DEC_ZX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, LDX_I, 0x01, STA_Z, 0x11, DEC_ZX, 0x10, LDA_Z, 0x11, 0x00 });
    try std.testing.expect(p.ac == 0x71);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "DEC_A" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_A, 0x10, 0x20, DEC_A, 0x10, 0x20, LDA_A, 0x10, 0x20, 0x00 });
    try std.testing.expect(p.ac == 0x71);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "DEX_I" {
    var p = try runTest(&[_]u8{ LDX_I, 0x22, DEX_I, 0x00 });
    try std.testing.expect(p.x == 0x21);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "LDA_I" {
    var p = try runTest(&[_]u8{ LDA_I, 0x82, 0x00 });
    try std.testing.expect(p.ac == 0x82);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(p.getNegativeFlag());
    (&p).deinit();

    p = try runTest(&[_]u8{ LDA_I, 0x00, 0x00 });
    try std.testing.expect(p.ac == 0x00);
    try std.testing.expect(p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "LDA_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x82, STA_Z, 0x10, LDA_I, 0x00, LDA_Z, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x82);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(p.getNegativeFlag());
    (&p).deinit();
}

test "LDA_ZX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x11, STA_Z, 0x21, LDA_I, 0x00, LDA_Z, 0x01, LDA_ZX, 0x21, 0x00 });
    try std.testing.expect(p.ac == 0x11);
    try std.testing.expect(!p.getZeroFlag());
    (&p).deinit();
}

test "LDA_IX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, STA_Z, 0x11, LDA_I, 0x20, STA_Z, 0x12, LDX_I, 0x01, LDA_I, 0x72, STA_A, 0x10, 0x20, LDA_I, 0xFF, LDA_IX, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x72);
    try std.testing.expect(!p.getZeroFlag());
    (&p).deinit();
}

test "LDA_IY" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, STA_Z, 0x10, LDA_I, 0x20, STA_Z, 0x11, LDY_I, 0x01, LDA_I, 0x72, STA_A, 0x11, 0x20, LDA_I, 0xFF, LDA_IY, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x72);
    try std.testing.expect(!p.getZeroFlag());
    (&p).deinit();
}

test "LDX_I" {
    var p = try runTest(&[_]u8{ LDX_I, 0x72, 0x00 });
    try std.testing.expect(p.x == 0x72);
    (&p).deinit();
}

test "LDX_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_Z, 0x10, LDA_I, 0x00, LDX_Z, 0x10, 0x00 });

    try std.testing.expect(p.x == 0x72);
    (&p).deinit();
}

test "LDY_I" {
    var p = try runTest(&[_]u8{ LDY_I, 0x72, 0x00 });
    try std.testing.expect(p.y == 0x72);
    (&p).deinit();
}

test "LDY_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_Z, 0x10, LDA_I, 0x00, LDY_Z, 0x10, 0x00 });
    try std.testing.expect(p.y == 0x72);
    (&p).deinit();
}

test "STA_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_Z, 0x10, 0x00 });
    try std.testing.expect(p.mem.mem[0x10] == 0x72);
    (&p).deinit();
}

test "STX_Z" {
    var p = try runTest(&[_]u8{ LDX_I, 0x72, STX_Z, 0x10, 0x00 });
    try std.testing.expect(p.mem.mem[0x10] == 0x72);
    (&p).deinit();
}

test "STY_Z" {
    var p = try runTest(&[_]u8{ LDY_I, 0x72, STY_Z, 0x10, 0x00 });
    try std.testing.expect(p.mem.mem[0x10] == 0x72);
    (&p).deinit();
}
