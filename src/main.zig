// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const Io = std.Io;
const mem = @import("./memory.zig");
const proc = @import("./processor.zig");
const ops = @import("./ops.zig");


const _6502_emul = @import("_6502_emul");




pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.log.info("Let's the show begin.", .{});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    var p = try proc.initProcessor(arena, 64_000);
    defer p.deinit();

    try p.show();

    const program = [_]u8{
        ops.LDA_I, 0xAA,
        ops.LDX_I, 0xAB,
        ops.LDY_I, 0xAC,
        ops.STA_Z, 0x20,
        ops.STX_Z, 0x21,
        ops.STY_Z, 0x22,
        ops.LDA_Z, 0x20,
        ops.STA_Z, 0x30,
        ops.LDX_Z, 0x21,
        ops.STX_Z, 0x31,
        ops.LDY_Z, 0x22,
        ops.STY_Z, 0x32,

        0x0};

    ops.initOpTable();

    ops.setProgram(&p, &program);

    ops.run(&p, 100);

    try p.show();


    const program2 = [_]u8{
        ops.LDA_I, 0b00000011,
        ops.AND_I, 0b00000001,
        0x00
    };

    p.reset();
    ops.setProgram(&p, &program2);
    ops.run(&p, 100);

    try p.show();
}


test "init memory " {
    std.log.info("testing init memory", .{});

    const ta = std.testing.allocator;

    var memory = try mem.initMemory(ta, 64_000);
    defer memory.deinit();

    try memory.show();

    try std.testing.expect(true);
}



test "init processor " {
    std.log.info("testing init processor", .{});

    const ta = std.testing.allocator;

    var p = try proc.initProcessor(ta, 64_000);
    defer p.deinit();

    try p.show();

    try std.testing.expect(true);
}
