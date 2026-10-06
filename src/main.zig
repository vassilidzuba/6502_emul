// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");
const Io = std.Io;
const mem = @import("./memory.zig");
const proc = @import("./processor.zig");
const ops = @import("./ops.zig");
const as = @import("./asm6502.zig");
const tester = @import("./tester.zig");


const _6502_emul = @import("_6502_emul");

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.log.info("Let's the show begin.", .{});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    var p = try proc.initProcessor(arena, 64_000);
    defer p.deinit();

    ops.initOpTable();

    try tester.runTest(init.io, arena, "testdata/test1.test");
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
