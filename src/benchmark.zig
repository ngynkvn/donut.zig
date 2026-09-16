const std = @import("std");
const tty = @import("tty.zig");
const Frame = @import("frame.zig").Frame;
const draw = @import("draw.zig");

pub fn main(init: std.process.Init) !void {
    var raw: tty.RawMode = .{
        .orig_termios = undefined,
        .tty = undefined,
        .io = init.io,
        .width = 80,
        .height = 24,
        .buffer = std.Io.Writer.Allocating.init(init.gpa),
    };
    defer raw.buffer.deinit();
    var plot = try Frame.init(init.gpa, raw.width, raw.height);
    defer plot.deinit();
    const frames = 2000;
    var bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..frames) |i| {
        const frame: f32 = @floatFromInt(i);
        try draw.torus(&plot, &raw, frame * 0.05, -0.4 + frame * 0.02);
        bytes += raw.buffer.written().len;
        raw.buffer.clearRetainingCapacity();
    }
    const elapsed = start.untilNow(init.io, .awake).toNanoseconds();
    std.debug.print("{d} frames: {d:.2} us/frame, {d} bytes/frame (rendering only, no terminal I/O)\n", .{
        frames, @as(f64, @floatFromInt(elapsed)) / frames / 1000, bytes / frames,
    });
}
