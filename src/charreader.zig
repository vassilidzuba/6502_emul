const std = @import("std");

pub const CharReader = struct {
    io: std.Io,
    buf: [128]u8 = undefined,
    file: std.Io.File,
    reader: std.Io.File.Reader,

    pub fn deinit(self: *CharReader) void {
        self.file.close(self.io);
    }

    pub fn initFromFilePath(self: *CharReader, io: std.Io, _: std.mem.Allocator, file_path: []const u8) !void {
        self.io = io;
        if (std.Io.Dir.cwd().openFile(io, file_path, .{
            .mode = .read_only, // optional args, used here for clarity
            .lock = .exclusive,
        })) |file| { // or catch, rather than if
            self.buf = undefined;
            self.reader = file.reader(io, &self.buf);
        } else |err| switch (err) {
            error.FileNotFound, error.AccessDenied => {
                std.log.info("unable to open file: {s}\n", .{file_path});
                // loop back to try another or something
            },
            else => |e| return e, // don't continue; rather, bomb out
        }
    }

    pub fn readByte(self: *CharReader) u8 {
        return self.reader.interface.takeByte() catch 0;
    }

    pub fn peekByte(self: *CharReader) u8 {
        return self.reader.interface.peekByte() catch 0;
    }
};
