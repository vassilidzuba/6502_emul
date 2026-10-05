// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const proc = @import("./processor.zig");
const cr = @import("./charreader.zig");
const ops = @import("./ops.zig");

const tkt_name: u8 = 1;
const tkt_u8: u8 = 2;
const tkt_u16: u8 = 3;
const tkt_endofline: u8 = 4;
const tkt_endoffile: u8 = 5;
const tkt_immediate: u8 = 6;
const tkt_zeropage: u8 = 7;
const tkt_zeropage_x: u8 = 8;
const tkt_zeropage_y: u8 = 9;
const tkt_absolute: u8 = 10;
const tkt_absolute_x: u8 = 11;
const tkt_absolute_y: u8 = 12;
const tkt_indirect_x: u8 = 13;
const tkt_indirect_y: u8 = 14;
const tkt_label: u8 = 15;
const tkt_accumulator: u8 = 16;

const AsmErrors = error{
    illegalParameter,
    illegalHexDigit,
    unknownOpcode,
};

const LabelError = error{
    notFound,
};

const Reference = struct {
    addr: u16,
    relative: bool,
};

const Label = struct {
    allocator: std.mem.Allocator,
    label: [32]u8,
    len: usize,
    addr: u16,
    references: std.ArrayList(Reference) = .empty,

    pub fn slice(self: *const Label) []const u8 {
        return self.label[0..self.len];
    }

    pub fn deinit(self: *const Label) void {
        self.references.deinit(self.allocator);
    }
};

const Token = struct {
    tkt: u8,
    buf: [16]u8,
    pos: usize,

    fn slice(self: *const Token) []const u8 {
        return self.buf[0..self.pos];
    }

    fn show(self: *const Token) void {
        if (self.tkt == tkt_name) {
            // std.log.info(">>> {d} - {s}", .{ self.tkt, self.buf[0..self.pos] });
            return;
        }
        if (self.tkt == tkt_endofline) {
            // std.log.info(">>> NEWLINE", .{});
            return;
        }
        if (self.tkt == tkt_endoffile) {
            // std.log.info(">>> END OF FILE", .{});
            return;
        }
        if (self.tkt == tkt_label) {
            // std.log.info(">>> END OF FILE", .{});
            return;
        }
        std.log.info(">>> unknown : {d}", .{self.tkt});
    }
};

fn asm6502(p: *proc.Processor, creader: *cr.CharReader) !void {
    var pos: usize = 0xCD00;
    var labelList: std.ArrayList(Label) = .empty;
    defer labelList.deinit(p.allocator);

    while (true) {
        const tk: Token = try nextToken(creader);
        (&tk).show();

        if (tk.tkt == tkt_endofline) {
            continue;
        }
        if (tk.tkt == tkt_endoffile) {
            displayLabels(&labelList);
            try updateReferences(p, &labelList);
            break;
        }

        if (tk.tkt == tkt_label) {
            try defineLabel(p.allocator, &labelList, tk.buf[0..tk.pos - 1], @intCast(pos));
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDA")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertImmediate(&tk2, p, pos, ops.LDA_I);
            pos = try insertZeropage(&tk2, p, pos, ops.LDA_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.LDA_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.LDA_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.LDA_AX);
            pos = try insertAbsoluteY(&tk2, p, pos, ops.LDA_AY);
            pos = try insertIndirectX(&tk2, p, pos, ops.LDA_IX);
            pos = try insertIndirectY(&tk2, p, pos, ops.LDA_IY);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDX")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertImmediate(&tk2, p, pos, ops.LDX_I);
            pos = try insertZeropage(&tk2, p, pos, ops.LDX_Z);
            pos = try insertZeropageY(&tk2, p, pos, ops.LDX_ZY);
            pos = try insertAbsolute(&tk2, p, pos, ops.LDX_A);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDY")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertImmediate(&tk2, p, pos, ops.LDY_I);
            pos = try insertZeropage(&tk2, p, pos, ops.LDY_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.LDY_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.LDY_A);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "INC")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertZeropage(&tk2, p, pos, ops.INC_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.INC_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.INC_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.INC_AX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "DEC")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertZeropage(&tk2, p, pos, ops.DEC_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.DEC_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.DEC_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.DEC_AX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "STA")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertZeropage(&tk2, p, pos, ops.STA_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.STA_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.STA_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.STA_AX);
            pos = try insertAbsoluteY(&tk2, p, pos, ops.STA_AY);
            pos = try insertIndirectX(&tk2, p, pos, ops.STA_IX);
            pos = try insertIndirectY(&tk2, p, pos, ops.STA_IY);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "ADC")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertImmediate(&tk2, p, pos, ops.ADC_I);
            pos = try insertZeropage(&tk2, p, pos, ops.ADC_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.ADC_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.ADC_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.ADC_AX);
            pos = try insertAbsoluteY(&tk2, p, pos, ops.ADC_AY);
            pos = try insertIndirectX(&tk2, p, pos, ops.ADC_IX);
            pos = try insertIndirectY(&tk2, p, pos, ops.ADC_IY);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "AND")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertImmediate(&tk2, p, pos, ops.AND_I);
            pos = try insertZeropage(&tk2, p, pos, ops.AND_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.AND_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.AND_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.AND_AX);
            pos = try insertAbsoluteY(&tk2, p, pos, ops.AND_AY);
            pos = try insertIndirectX(&tk2, p, pos, ops.AND_IX);
            pos = try insertIndirectY(&tk2, p, pos, ops.AND_IY);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "ASL")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertAccumulator(&tk2, p, pos, ops.ASL_I);
            pos = try insertZeropage(&tk2, p, pos, ops.ASL_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.ASL_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.ASL_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.ASL_AX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LSR")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertAccumulator(&tk2, p, pos, ops.LSR_I);
            pos = try insertZeropage(&tk2, p, pos, ops.LSR_Z);
            pos = try insertZeropageX(&tk2, p, pos, ops.LSR_ZX);
            pos = try insertAbsolute(&tk2, p, pos, ops.LSR_A);
            pos = try insertAbsoluteX(&tk2, p, pos, ops.LSR_AX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "DEX")) {
            pos = try insertImplied(p, pos, ops.DEX_I);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "INX")) {
            pos = try insertImplied(p, pos, ops.INX_I);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "DEY")) {
            pos = try insertImplied(p, pos, ops.DEY_I);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "INY")) {
            pos = try insertImplied(p, pos, ops.INY_I);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "CLC")) {
            pos = try insertImplied(p, pos, ops.CLC);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "SEC")) {
            pos = try insertImplied(p, pos, ops.SEC);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "NOP")) {
            pos = try insertImplied(p, pos, ops.NOP);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "PHA")) {
            pos = try insertImplied(p, pos, ops.PHA);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "PHP")) {
            pos = try insertImplied(p, pos, ops.PHP);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "PLA")) {
            pos = try insertImplied(p, pos, ops.PLA);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "PLP")) {
            pos = try insertImplied(p, pos, ops.PLP);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TAX")) {
            pos = try insertImplied(p, pos, ops.TAX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TAY")) {
            pos = try insertImplied(p, pos, ops.TAY);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TSX")) {
            pos = try insertImplied(p, pos, ops.TSX);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TXA")) {
            pos = try insertImplied(p, pos, ops.TXA);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TXS")) {
            pos = try insertImplied(p, pos, ops.TXS);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "TYA")) {
            pos = try insertImplied(p, pos, ops.TYA);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "RTS")) {
            pos = try insertImplied(p, pos, ops.RTS);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "JMP")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertAbsoluteAddress(&tk2, p, pos, ops.JMP_A, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "JSR")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertAbsoluteAddress(&tk2, p, pos, ops.JSR_A, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BCC")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BCC, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BCS")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BCS, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BEQ")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BEQ, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BNE")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BNE, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BMI")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BMI, &labelList);
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "BPL")) {
            const tk2: Token = try nextToken(creader);

            pos = try insertRelativeAddress(&tk2, p, pos, ops.BPL, &labelList);
        } else {
            std.log.err("Unknown opcode: {s}", .{tk.buf[0..tk.pos]});
            return AsmErrors.unknownOpcode;
        }
    }
}

fn insertImplied(p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    p.mem.mem[pc] = opcode;
    pc = pc + 1;
    return pc;
}

fn insertImmediate(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_immediate) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        p.mem.mem[pc] = try getImmediate(tk.buf[0..tk.pos]);
        pc = pc + 1;
    }
    return pc;
}

fn insertZeropage(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_zeropage) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        p.mem.mem[pc] = try getZeropage(tk.buf[0..tk.pos]);
        pc = pc + 1;
    }
    return pc;
}

fn insertZeropageX(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_zeropage_x) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        p.mem.mem[pc] = try getZeropage(tk.buf[0 .. tk.pos - 2]);
        pc = pc + 1;
    }
    return pc;
}

fn insertZeropageY(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_zeropage_y) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        p.mem.mem[pc] = try getZeropage(tk.buf[0..tk.pos]);
        pc = pc + 1;
    }
    return pc;
}

fn insertAbsolute(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_absolute) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getAbsolute(tk.buf[0..tk.pos]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
        p.mem.mem[pc] = @intCast(address >> 8);
        pc = pc + 1;
    }
    return pc;
}

fn insertAbsoluteX(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_absolute_x) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getAbsolute(tk.buf[0 .. tk.pos - 2]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
        p.mem.mem[pc] = @intCast(address >> 8);
        pc = pc + 1;
    }
    return pc;
}

fn insertAbsoluteY(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_absolute_y) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getAbsolute(tk.buf[0 .. tk.pos - 2]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
        p.mem.mem[pc] = @intCast(address >> 8);
        pc = pc + 1;
    }
    return pc;
}

fn insertIndirectX(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_indirect_x) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getZeropage(tk.buf[1 .. tk.pos - 3]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
    }
    return pc;
}

fn insertIndirectY(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_indirect_y) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getZeropage(tk.buf[1 .. tk.pos - 3]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
    }
    return pc;
}

fn insertAccumulator(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_accumulator) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
    }
    return pc;
}

fn insertAbsoluteAddress(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8, labelList: *std.ArrayList(Label)) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_absolute) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getAbsolute(tk.buf[0 .. tk.pos - 2]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
        p.mem.mem[pc] = @intCast(address >> 8);
        pc = pc + 1;
    } else {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        try defineLabelReference(p.allocator, labelList, tk.slice(), @intCast(pc), false);
        p.mem.mem[pc] = 0;
        pc = pc + 1;
        p.mem.mem[pc] = 0;
        pc = pc + 1;
    }
    return pc;
}

fn insertRelativeAddress(tk: *const Token, p: *proc.Processor, pc1: usize, opcode: u8, labelList: *std.ArrayList(Label)) !usize {
    var pc = pc1;
    if (tk.tkt == tkt_zeropage) {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        const address = try getZeropage(tk.buf[0 .. tk.pos - 2]);
        p.mem.mem[pc] = @intCast(address & 0x00FF);
        pc = pc + 1;
    } else {
        p.mem.mem[pc] = opcode;
        pc = pc + 1;
        try defineLabelReference(p.allocator, labelList, tk.slice(), @intCast(pc), true);
        p.mem.mem[pc] = 0;
        pc = pc + 1;
    }
    return pc;
}

fn nextToken(creader: *cr.CharReader) !Token {
    var pos: usize = 0;
    var buf: [128]u8 = undefined;

    var ch: u8 = undefined;
    while (true) {
        ch = creader.peekByte();
        if (ch == 0) {
            return .{ .tkt = tkt_endoffile, .buf = undefined, .pos = 0 };
        }
        if (ch == ' ') {
            _ = creader.readByte();
            continue;
        }
        if (ch == '\n') {
            _ = creader.readByte();
            return .{ .tkt = tkt_endofline, .buf = undefined, .pos = 0 };
        }
        if (ch == ';') {
            while (true) {
                ch = creader.readByte();
                if (ch == '\n') {
                    break;
                }
                if (ch == 0) {
                    break;
                }
            }
            continue;
        }
        break;
    }

    while (true) {
        ch = creader.peekByte();
        if (ch == ' ' or ch == '\n' or ch == 0 or ch == ';') {
            break;
        }
        ch = creader.readByte();
        buf[pos] = ch;
        pos = pos + 1;
    }

    var tk: Token = undefined;
    tk.tkt = tkt_name;
    for (0..pos) |i| {
        tk.buf[i] = buf[i];
    }

    // std.log.info(">>>>>>> {d} - {s}", .{ pos, buf[0..pos] });

    if (tk.buf[0] == '#') {
        tk.tkt = tkt_immediate;
    } else if (tk.buf[0] == '$' and pos == 3) {
        tk.tkt = tkt_zeropage;
    } else if (tk.buf[0] == '$' and pos == 5 and tk.buf[3] == ',' and tk.buf[4] == 'X') {
        tk.tkt = tkt_zeropage_x;
    } else if (tk.buf[0] == '$' and pos == 5 and tk.buf[3] == ',' and tk.buf[4] == 'Y') {
        tk.tkt = tkt_zeropage_y;
    } else if (tk.buf[0] == '$' and pos == 5) {
        tk.tkt = tkt_absolute;
    } else if (tk.buf[0] == '$' and pos == 7 and tk.buf[5] == ',' and tk.buf[6] == 'X') {
        tk.tkt = tkt_absolute_x;
    } else if (tk.buf[0] == '$' and pos == 7 and tk.buf[5] == ',' and tk.buf[6] == 'Y') {
        tk.tkt = tkt_absolute_y;
    } else if (tk.buf[0] == '(' and tk.buf[1] == '$' and pos == 7 and tk.buf[4] == ',' and tk.buf[5] == 'X' and tk.buf[6] == ')') {
        tk.tkt = tkt_indirect_x;
    } else if (tk.buf[0] == '(' and tk.buf[1] == '$' and pos == 7 and tk.buf[4] == ')' and tk.buf[5] == ',' and tk.buf[6] == 'Y') {
        tk.tkt = tkt_indirect_y;
    } else if (pos > 1 and tk.buf[pos - 1] == ':') {
        tk.tkt = tkt_label;
    } else if (pos == 1 and tk.buf[0] == 'A') {
        tk.tkt = tkt_accumulator;
    }

    tk.pos = pos;

    return tk;
}

pub fn asm6502File(io: std.Io, allocator: std.mem.Allocator, p: *proc.Processor, file_path: []const u8) !void {
    var creader: cr.CharReader = undefined;
    try creader.initFromFilePath(io, allocator, file_path);
    try asm6502(p, &creader);
}

pub fn getImmediate(s: []const u8) !u8 {
    if (s.len == 4) {
        return getU8(s[2..4]);
    } else if (s.len == 10) {
        return getBinary(s[2..10]);
    } else {
        return AsmErrors.illegalParameter;
    }
}

pub fn getZeropage(s: []const u8) !u8 {
    if (s.len != 3) {
        return AsmErrors.illegalParameter;
    } else {
        return getU8(s[1..3]);
    }
}

pub fn getAbsolute(s: []const u8) !u16 {
    if (s.len != 5) {
        return AsmErrors.illegalParameter;
    } else {
        return getU16(s[1..5]);
    }
}

pub fn getU8(s: []const u8) !u8 {
    return try getDigit(s[0]) * 16 + try getDigit(s[1]);
}

pub fn getBinary(s: []const u8) !u8 {
    var val: u8 = 0;
    for (s) |ch| {
        if (ch == '1') {
            val = val + val + 1;
        } else if (ch == '0') {
            val = val + val;
        }
    }
    return val;
}

pub fn getU16(s: []const u8) !u16 {
    var x: u16 = try getDigit(s[0]);
    x = x * 16 + try getDigit(s[1]);
    x = x * 16 + try getDigit(s[2]);
    x = x * 16 + try getDigit(s[3]);
    return x;
}

pub fn getDigit(ch: u8) !u8 {
    if ('0' <= ch and '9' >= ch) {
        return ch - '0';
    } else if ('A' <= ch and 'F' >= ch) {
        return ch - 'A' + 10;
    } else if ('a' <= ch and 'f' >= ch) {
        return ch - 'a' + 10;
    } else {
        std.log.info(">>> illegal hex digit : {c}", .{ch});
        return AsmErrors.illegalHexDigit;
    }
}

fn defineLabel(allocator: std.mem.Allocator, list: *std.ArrayList(Label), label: []const u8, pc: u16) !void {

    if (getLabel(list, label)) |ls| {
        ls.addr = pc;
    } else |_| {
        var ls: Label = undefined;
        ls.allocator = allocator;
        ls.addr = pc;
        ls.len = label.len;
        for (0..ls.len) |ii| {
            ls.label[ii] = label[ii];
        }
        ls.references = .empty;
        try list.append(allocator, ls);
    }
}

fn defineLabelReference(allocator: std.mem.Allocator, list: *std.ArrayList(Label), label: []const u8, addr: u16, relative: bool) !void {
    if (getLabel(list, label)) |ls| {
        const ref : Reference = .{.addr = addr, .relative = relative};
        try ls.references.append(allocator, ref);
    } else |_| {
        var ls: Label = undefined;
        ls.allocator = allocator;
        ls.len = label.len;
        for (0..ls.len) |ii| {
            ls.label[ii] = label[ii];
        }

        ls.references = .empty;
        const ref : Reference = .{.addr = addr, .relative = relative};
        try ls.references.append(allocator, ref);

        try list.append(allocator, ls);
    }
}

fn getLabel(labelList: *std.ArrayList(Label), label: []const u8) !*Label {
    for (0..labelList.items.len) |ii| {
        if (std.mem.eql(u8, labelList.items[ii].slice(), label)) {
            return &labelList.items[ii];
        }
    }
    return LabelError.notFound;
}

fn displayLabels(list: *std.ArrayList(Label)) void {
    std.log.info("labels:", .{});
    for (list.items) |ls| {
        std.log.info("  label {s} at {X}", .{ ls.slice(), ls.addr });
        for (ls.references.items) |x| {
            var rel = "false";
            if (x.relative) {
                rel = "true ";
            }
            std.log.info("      {X}  relative={s}", .{x.addr, rel});
        }
    }
}

fn updateReferences(p: *proc.Processor, list: *std.ArrayList(Label)) !void {
    for (list.items) |l| {
        for (l.references.items) |ref| {
            if (ref.relative) {
                var rel: i8 = undefined;
                if (l.addr > ref.addr) {
                    rel = @intCast(l.addr - ref.addr);
                    std.log.info("rel {X}", .{l.addr - ref.addr});
                } else {
                    rel = @intCast(ref.addr - l.addr);
                    rel = - rel;
                }
                p.mem.mem[ref.addr] = @bitCast(rel);
            } else {
                p.mem.mem[ref.addr] = @intCast(l.addr & 0x00FF);
                p.mem.mem[ref.addr + 1] = @intCast(l.addr >> 8);
            }
        }
    }
}
