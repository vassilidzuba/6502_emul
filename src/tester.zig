// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const proc = @import("./processor.zig");
const cr = @import("./charreader.zig");
const ops = @import("./ops.zig");
const as = @import("./asm6502.zig");

const TesterErrors = error{
    unknownCommand,
    assertionFails,
    illegalParameter,
    illegalHexDigit,
};

const tkt_name: u8 = 1;
const tkt_eol: u8 = 2;
const tkt_eof: u8 = 4;

const Token = struct {
    tkt: u8,
    buf: [32]u8,
    pos: usize,

    pub fn slice(self: *const Token) []const u8 {
        return self.buf[0..self.pos];
    }

    pub fn show(self: *const Token) void {
        std.log.info(">>> {s}", .{self.buf[0..self.pos]});
    }
};

pub fn runTest(io: std.Io, allocator: std.mem.Allocator, file_path: []const u8) !void {
    var p = try proc.initProcessor(allocator, 64_000);
    defer p.deinit();

    var creader: cr.CharReader = undefined;
    try creader.initFromFilePath(io, allocator, file_path);
    try runTestFromReader(io, allocator, &creader, &p);
}

fn runTestFromReader(io: std.Io, allocator: std.mem.Allocator, creader: *cr.CharReader, p: *proc.Processor) !void {
    while (true) {
        const tk: Token = try nextToken(creader);

        //tk.show();

        if (tk.tkt == tkt_eol) {
            continue;
        } else if (tk.tkt == tkt_eof) {
            break;
        } else if (std.mem.eql(u8, tk.slice(), "run")) {
            const tk2: Token = try nextToken(creader);
            p.reset();
            try as.asm6502File(io, allocator, p, tk2.slice());
            try p.show();
            ops.run(p, 100);
            try p.show();
        } else if (std.mem.eql(u8, tk.slice(), "assert")) {
            const tk2: Token = try nextToken(creader);
            const addr = tk2.slice();
            const tk3: Token = try nextToken(creader);
            const sval = tk3.slice();

            if (std.mem.eql(u8, addr, "A")) {
                const val = try getU8(sval);
                const ok = p.ac == val;
                if (!ok) {
                    std.log.info(">>> assertion failed : {s} {s}", .{ addr, sval });
                    return TesterErrors.assertionFails;
                }
                std.log.info(">>> assertion suceeded : {s} {s}", .{ addr, sval });
            } else if (std.mem.eql(u8, addr, "X")) {
                const val = try getU8(sval);
                const ok = p.x == val;
                if (!ok) {
                    std.log.info(">>> assertion failed : {s} {s}", .{ addr, sval });
                    return TesterErrors.assertionFails;
                }
                std.log.info(">>> assertion suceeded : {s} {s}", .{ addr, sval });
            } else if (std.mem.eql(u8, addr, "Y")) {
                const val = try getU8(sval);
                const ok = p.y == val;
                if (!ok) {
                    std.log.info(">>> assertion failed : {s} {s}", .{ addr, sval });
                    return TesterErrors.assertionFails;
                }
                std.log.info(">>> assertion suceeded : {s} {s}", .{ addr, sval });
            } else if (addr[0] == '@' and addr.len == 3) {
                const val = try getU8(sval);
                const addr2 = try getU8(addr);
                const ok = p.mem.mem[addr2] == val;
                if (!ok) {
                    std.log.info(">>> assertion failed : {d} {d}", .{ addr2, val });
                    return TesterErrors.assertionFails;
                }
                std.log.info(">>> assertion suceeded : {s} {s}", .{ addr, sval });
            } else if (addr[0] == '@' and addr.len == 5) {
                const val = try getU8(sval);
                const addr2 = try getU16(addr);
                const ok = p.mem.mem[addr2] == val;
                if (!ok) {
                    std.log.info(">>> assertion failed : {s} {s}", .{ addr, sval });
                    return TesterErrors.assertionFails;
                }
                std.log.info(">>> assertion suceeded : {s} {s}", .{ addr, sval });
            } else {
                std.log.info(">>> unknown command : {d} {s}", .{ tk.tkt, tk.slice() });
                (&tk).show();
                return TesterErrors.unknownCommand;
            }
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
            return .{ .tkt = tkt_eof, .buf = undefined, .pos = 0 };
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
        return .{ .tkt = tkt_eol, .buf = undefined, .pos = 0 };
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
    for (0..pos) |i| {
        tk.buf[i] = buf[i];
    }

    tk.pos = pos;

    return tk;
}

pub fn getU8(s: []const u8) !u8 {
    if (s.len != 3) {
        return TesterErrors.illegalParameter;
    } else {
        return try getDigit(s[1]) * 16 + try getDigit(s[2]);
    }
}

pub fn getU16(s: []const u8) !u16 {
    var x: u16 = try getDigit(s[1]);
    x = x * 16 + try getDigit(s[2]);
    x = x * 16 + try getDigit(s[3]);
    x = x * 16 + try getDigit(s[4]);
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
        return TesterErrors.illegalHexDigit;
    }
}
