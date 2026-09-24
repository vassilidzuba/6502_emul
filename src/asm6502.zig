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

const AsmErrors = error{
    illegalParameter,
    illegalHexDigit,
    unknownOpcode,
};

const Token = struct {
    tkt: u8,
    buf: [16]u8,
    pos: usize,

    fn show(self: *const Token) void {
        if (self.tkt == tkt_name) {
            std.log.info(">>> {d} - {s}", .{ self.tkt, self.buf[0..self.pos] });
            return;
        }
        if (self.tkt == tkt_endofline) {
            std.log.info(">>> NEWLINE", .{});
            return;
        }
        if (self.tkt == tkt_endoffile) {
            std.log.info(">>> END OF FILE", .{});
            return;
        }
        std.log.info(">>> unknown : {d}", .{self.tkt});
    }
};

fn asm6502(p: *proc.Processor, creader: *cr.CharReader) !void {
    var pos: usize = 0xCD00;

    while (true) {
        const tk: Token = try nextToken(creader);
        (&tk).show();

        if (tk.tkt == tkt_endofline) {
            continue;
        }
        if (tk.tkt == tkt_endoffile) {
            break;
        }

        if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDA")) {
            const tk2: Token = try nextToken(creader);

            if (tk2.tkt == tkt_immediate) {
                p.mem.mem[pos] = ops.LDA_I;
                pos = pos + 1;
                p.mem.mem[pos] = try getImmediate(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage) {
                p.mem.mem[pos] = ops.LDA_Z;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage_x) {
                p.mem.mem[pos] = ops.LDA_ZX;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos - 2]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_absolute) {
                p.mem.mem[pos] = ops.LDA_A;
                pos = pos + 1;
                const address = try getAbsolute(tk2.buf[0..tk2.pos]);
                p.mem.mem[pos] = @intCast(address & 0x00FF);
                pos = pos + 1;
                p.mem.mem[pos] = @intCast(address >> 8);
                pos = pos + 1;
            }
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDX")) {
            const tk2: Token = try nextToken(creader);

            if (tk2.tkt == tkt_immediate) {
                p.mem.mem[pos] = ops.LDX_I;
                pos = pos + 1;
                p.mem.mem[pos] = try getImmediate(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage) {
                p.mem.mem[pos] = ops.LDX_Z;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage_y) {
                p.mem.mem[pos] = ops.LDX_ZY;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos - 2]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_absolute) {
                p.mem.mem[pos] = ops.LDX_A;
                pos = pos + 1;
                const address = try getAbsolute(tk2.buf[0..tk2.pos]);
                p.mem.mem[pos] = @intCast(address & 0x00FF);
                pos = pos + 1;
                p.mem.mem[pos] = @intCast(address >> 8);
                pos = pos + 1;
            }
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "LDY")) {
            const tk2: Token = try nextToken(creader);

            if (tk2.tkt == tkt_immediate) {
                p.mem.mem[pos] = ops.LDY_I;
                pos = pos + 1;
                p.mem.mem[pos] = try getImmediate(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage) {
                p.mem.mem[pos] = ops.LDY_Z;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_zeropage_x) {
                p.mem.mem[pos] = ops.LDY_ZX;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos - 2]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_absolute) {
                p.mem.mem[pos] = ops.LDY_A;
                pos = pos + 1;
                const address = try getAbsolute(tk2.buf[0..tk2.pos]);
                p.mem.mem[pos] = @intCast(address & 0x00FF);
                pos = pos + 1;
                p.mem.mem[pos] = @intCast(address >> 8);
                pos = pos + 1;
            }
        } else if (std.mem.eql(u8, tk.buf[0..tk.pos], "STA")) {
            const tk2: Token = try nextToken(creader);

            if (tk2.tkt == tkt_zeropage) {
                p.mem.mem[pos] = ops.STA_Z;
                pos = pos + 1;
                p.mem.mem[pos] = try getZeropage(tk2.buf[0..tk2.pos]);
                pos = pos + 1;
            } else if (tk2.tkt == tkt_absolute) {
                p.mem.mem[pos] = ops.STA_A;
                pos = pos + 1;
                const address = try getAbsolute(tk2.buf[0..tk2.pos]);
                p.mem.mem[pos] = @intCast(address & 0x00FF);
                pos = pos + 1;
                p.mem.mem[pos] = @intCast(address >> 8);
                pos = pos + 1;
            }
        } else {
            return AsmErrors.unknownOpcode;
        }
    }
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
        break;
    }

    ch = creader.peekByte();
    if (ch == '\n') {
        ch = creader.readByte();
        return .{ .tkt = tkt_endofline, .buf = undefined, .pos = 0 };
    }

    while (true) {
        ch = creader.peekByte();
        if (ch == ' ' or ch == '\n' or ch == 0) {
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

    std.log.info(">>>>>>> {d} - {s}", .{pos, buf[0..pos]});

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
    } else if (tk.buf[0] == '$' and pos == 7 and tk.buf[5] == ',' and tk.buf[6] == 'X') {
        tk.tkt = tkt_absolute_y;
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
    if (s.len != 4) {
        return AsmErrors.illegalParameter;
    } else {
        return getU8(s[2..4]);
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
        return ch - 'A';
    } else if ('a' <= ch and 'f' >= ch) {
        return ch - 'a';
    } else {
        std.log.info(">>> illegal hex digit : {c}", .{ch});
        return AsmErrors.illegalHexDigit;
    }
}
