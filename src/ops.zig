// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const proc = @import("./processor.zig");

pub const NUL = 0;
pub const ADC_I = 0x69;
pub const ADC_Z = 0x65;
pub const ADC_ZX = 0x75;
pub const ADC_A = 0x60;
pub const ADC_AX = 0x70;
pub const ADC_AY = 0x79;
pub const ADC_IX = 0x61;
pub const ADC_IY = 0x71;

pub const AND_I = 0x29;
pub const AND_Z = 0x25;
pub const AND_ZX = 0x35;
pub const AND_A = 0x20;
pub const AND_AX = 0x30;
pub const AND_AY = 0x39;
pub const AND_IX = 0x21;
pub const AND_IY = 0x31;

pub const CLC_I = 0x18;

pub const DEC_Z = 0xC6;
pub const DEC_ZX = 0xD6;
pub const DEC_A = 0xCE;
pub const DEC_AX = 0xDE;
pub const DEX_I = 0xCA;
pub const DEY_I = 0x88;
pub const INC_Z = 0xE6;
pub const INC_ZX = 0xF6;
pub const INC_A = 0xEE;
pub const INC_AX = 0xFE;
pub const INX_I = 0xE8;
pub const INY_I = 0xC8;
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

    addOpTable(ADC_I, exec_ADC_I);
    addOpTable(ADC_Z, exec_ADC_Z);
    addOpTable(ADC_ZX, exec_ADC_ZX);
    addOpTable(ADC_A, exec_ADC_A);
    addOpTable(ADC_AX, exec_ADC_AX);
    addOpTable(ADC_AY, exec_ADC_AY);
    addOpTable(ADC_IX, exec_ADC_IX);
    addOpTable(ADC_IY, exec_ADC_IY);

    addOpTable(AND_I, exec_AND_I);
    addOpTable(AND_Z, exec_AND_Z);
    addOpTable(AND_ZX, exec_AND_ZX);
    addOpTable(AND_A, exec_AND_A);
    addOpTable(AND_AX, exec_AND_AX);
    addOpTable(AND_AY, exec_AND_AY);
    addOpTable(AND_IX, exec_AND_IX);
    addOpTable(AND_IY, exec_AND_IY);

    addOpTable(CLC_I, exec_CLC_I);

    addOpTable(DEC_Z, exec_DEC_Z);
    addOpTable(DEC_ZX, exec_DEC_ZX);
    addOpTable(DEC_A, exec_DEC_A);
    addOpTable(DEC_AX, exec_DEC_AX);
    addOpTable(DEX_I, exec_DEX_I);
    addOpTable(DEY_I, exec_DEY_I);

    addOpTable(INC_Z, exec_INC_Z);
    addOpTable(INC_ZX, exec_INC_ZX);
    addOpTable(INC_A, exec_INC_A);
    addOpTable(INC_AX, exec_INC_AX);
    addOpTable(INX_I, exec_INX_I);
    addOpTable(INY_I, exec_INY_I);

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

const INVALID_ADDRESS: usize = std.math.maxInt(u32);

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
    return adr + p.x;
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

fn exec_ADC(p: *proc.Processor, adr: usize) void {
    var val: u16 = undefined;
    if (adr == INVALID_ADDRESS) {
        val = p.mem.mem[p.pc];
        p.pc = p.pc + 1;
    } else {
        val = p.mem.mem[adr];
    }
    val = val + p.ac;
    if (val & 0xFF00 == 0) {
        p.setCarryFlag(false);
    } else {
        p.setCarryFlag(true);
        val = val & 0x00FF;
    }
    p.ac = @intCast(val);
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
}

fn exec_ADC_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    exec_ADC(p, INVALID_ADDRESS);
    cy.* = cy.* - 2;
}

fn exec_ADC_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_AX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_AX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);

    std.log.info("address is {X}", .{adr});
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_AY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_AY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteYAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_IX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_IX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectXAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_ADC_IY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running ADC_IY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectYAddress(p);
    exec_ADC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND(p: *proc.Processor, adr: usize) void {
    var val: u16 = undefined;
    if (adr == INVALID_ADDRESS) {
        val = p.mem.mem[p.pc];
        p.pc = p.pc + 1;
    } else {
        val = p.mem.mem[adr];
    }

    val = val & p.ac;

    p.ac = @intCast(val);
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
}

fn exec_AND_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    exec_AND(p, INVALID_ADDRESS);
    cy.* = cy.* - 2;
}

fn exec_AND_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_AX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_AX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);

    std.log.info("address is {X}", .{adr});
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_AY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_AY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteYAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_IX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_IX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectXAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_AND_IY(p: *proc.Processor, cy: *i32) void {
    std.log.info("running AND_IY, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getIndirectYAddress(p);
    exec_AND(p, adr);
    cy.* = cy.* - 2;
}

fn exec_CLC_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running CLC_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    p.setCarryFlag(false);
    cy.* = cy.* - 2;
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
    std.log.info("running DEC_AX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_DEX_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running DEX_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    var val: u16 = p.x;
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
    var val: u16 = p.y;
    if (val == 0) {
        val = 0xFF;
    } else {
        val = val - 1;
    }
    p.y = @intCast(val);
    cy.* = cy.* - 2;
}

fn exec_INC(p: *proc.Processor, adr: usize) void {
    var val: u16 = p.mem.mem[adr];
    if (val == 255) {
        val = 0;
    } else {
        val = val + 1;
    }
    p.mem.mem[adr] = @intCast(val);
    p.setZeroFlag(val == 0);
    p.setNegativeFlag(val & 0b10000000 != 0);
}

fn exec_INC_Z(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INC_Z, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageAddress(p);
    exec_INC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_INC_ZX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INC_ZX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getZeropageXAddress(p);
    exec_INC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_INC_A(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INC_A, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteAddress(p);
    exec_INC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_INC_AX(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INC_AX, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    const adr = getAbsoluteXAddress(p);
    exec_DEC(p, adr);
    cy.* = cy.* - 2;
}

fn exec_INX_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INX_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    var val: u16 = p.x;
    if (val == 0xFF) {
        val = 0x00;
    } else {
        val = val + 1;
    }
    p.x = @intCast(val);
    cy.* = cy.* - 2;
}

fn exec_INY_I(p: *proc.Processor, cy: *i32) void {
    std.log.info("running INY_I, (cycle {d})", .{cy.*});
    p.pc = p.pc + 1;
    var val: u16 = p.y;
    if (val == 0xFF) {
        val = 0x00;
    } else {
        val = val + 1;
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

test "ADC_I" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, ADC_I, 0x20, 0x00 });
    try std.testing.expect(p.ac == 0x30);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "ADC_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0xF1, STA_Z, 0x10, LDA_I, 0xF1, ADC_Z, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0xE2);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(p.getNegativeFlag());
    try std.testing.expect(p.getCarryFlag());
    (&p).deinit();
}

test "ADC_ZX" {
    var p = try runTest(&[_]u8{ LDA_I, 0xF1, STA_Z, 0x11, LDA_I, 0xF1, LDX_I, 0x01, ADC_ZX, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0xE2);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(p.getNegativeFlag());
    try std.testing.expect(p.getCarryFlag());
    (&p).deinit();
}

test "ADC_A" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, STA_Z, 0x10, LDA_I, 0x20, STA_Z, 0x11, STA_A, 0x10, LDA_I, 0x11, ADC_A, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x20);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "ADC_AX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x20, STA_A, 0x11, 0x20, LDA_I, 0x22, LDX_I, 0x01, ADC_AX, 0x10, 0x20, 0x00 });
    try std.testing.expect(p.ac == 0x42);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "ADC_AY" {
    var p = try runTest(&[_]u8{ LDA_I, 0x20, STA_A, 0x11, 0x20, LDA_I, 0x22, LDY_I, 0x01, ADC_AY, 0x10, 0x20, 0x00 });
    try std.testing.expect(p.ac == 0x42);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "ADC_IX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, STA_Z, 0x11, LDA_I, 0x20, STA_Z, 0x12, LDA_I, 0x42, STA_A, 0x10, 0x20, LDX_I, 0x01, LDA_I, 0x12, ADC_IX, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x54);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "ADC_IY" {
    var p = try runTest(&[_]u8{ LDA_I, 0x10, STA_Z, 0x10, LDA_I, 0x20, STA_Z, 0x11, LDA_I, 0x42, STA_A, 0x11, 0x20, LDY_I, 0x01, LDA_I, 0x12, ADC_IY, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x54);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    try std.testing.expect(!p.getCarryFlag());
    (&p).deinit();
}

test "CLC_I" {
    var p = try runTest(&[_]u8{ LDA_I, 0x80, ADC_I, 0x80, CLC_I, 0x00 });
    try std.testing.expect(! p.getCarryFlag());
    (&p).deinit();
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

test "DEY_I" {
    var p = try runTest(&[_]u8{ LDY_I, 0x22, DEY_I, 0x00 });
    try std.testing.expect(p.y == 0x21);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "INC_Z" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_Z, 0x10, INC_Z, 0x10, LDA_Z, 0x10, 0x00 });
    try std.testing.expect(p.ac == 0x73);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "INC_ZX" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, LDX_I, 0x01, STA_Z, 0x11, INC_ZX, 0x10, LDA_Z, 0x11, 0x00 });
    try std.testing.expect(p.ac == 0x73);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "INC_A" {
    var p = try runTest(&[_]u8{ LDA_I, 0x72, STA_A, 0x10, 0x20, INC_A, 0x10, 0x20, LDA_A, 0x10, 0x20, 0x00 });
    try std.testing.expect(p.ac == 0x73);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "INX_I" {
    var p = try runTest(&[_]u8{ LDX_I, 0x22, INX_I, 0x00 });
    try std.testing.expect(p.x == 0x23);
    try std.testing.expect(!p.getZeroFlag());
    try std.testing.expect(!p.getNegativeFlag());
    (&p).deinit();
}

test "INY_I" {
    var p = try runTest(&[_]u8{ LDY_I, 0x20, INY_I, 0x00 });
    try std.testing.expect(p.y == 0x21);
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
