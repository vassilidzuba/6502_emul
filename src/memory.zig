// Copyright 2026, Vassili Dzuba
// Distributed under the MIT license

const std = @import("std");

pub const Memory = struct {
  allocator: std.mem.Allocator,
  mem: [] u8,
  memsize: u16,

  pub fn deinit(self: *Memory) void {
      self.allocator.free(self.mem);
  }

  pub fn show(self: *Memory) !void {
      std.log.info("memory:", .{});

      var line: usize = 0;
      while (true) {
          if (line >= self.mem.len / 16) {
              break;
          }

          if (self.notEmpty(line)) {
              var buffer: [1024]u8 = undefined;
              // std.log.info("    {X:0>4}", .{line * 16});
              const buf = try std.fmt.bufPrint(&buffer, "    {X:0>4}", .{line * 16});
              var pos = buf.len;

              for (0..16) |ii| {
                  const buf2 = try std.fmt.bufPrint(buffer[pos..], " {X:0>2}", .{self.mem[line * 16 + ii]});
                  pos = pos + buf2.len;
              }

              std.log.info("    {s}", .{buffer[0..pos]});
          }

          line  = line + 1;
      }
  }

  fn notEmpty(self: *Memory, line: usize) bool {
      for (0..16) |ii| {
          if (self.mem[line * 16 + ii] != 0) {
              return true;
          }
      }
      return false;
  }


  pub fn reset(self: *Memory) void {
      @memset(self.mem, 0);
  }

};

pub fn initMemory(allocator: std.mem.Allocator, memsize: u16) !Memory {
    var mem: Memory = undefined;
    mem.allocator = allocator;
    mem.memsize = memsize;

    mem.mem = try allocator.alloc(u8, memsize);
    @memset(mem.mem, 0);

    return mem;
}
