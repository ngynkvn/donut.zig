const std = @import("std");

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const plotter = @import("plotter.zig");

/// Line test
pub fn test_line(plot: *plotter.Plotter, raw: tty.RawMode) !void {
    const rw: f32 = @floatFromInt(raw.width);
    const rh: f32 = @floatFromInt(raw.height);
    var timer = try std.time.Timer.start();
    try draw.line(plot, .{ .x = 0, .y = rh - 0.1 }, .{ .x = rw, .y = rh - 0.1 });
    try draw.line(plot, .{ .x = 0, .y = rh - 1 }, .{ .x = rw, .y = rh - 1 });
    try draw.line(plot, .{ .x = 0, .y = rh - 2 }, .{ .x = rw, .y = rh - 2 });
    try raw.goto(0, raw.height);
    try raw.printTermSize();
    const elapsed: f32 = @floatFromInt(timer.lap());
    try draw.box(raw, .{ .x = 5, .y = rh - 5 }, .{ .x = 80, .y = rh - 20 }, false);
    try raw.goto(6, raw.height - 6);
    try raw.print("{d} ms." ++ tty.E.CURSOR_DOWN, .{(elapsed) / std.time.ns_per_ms});
    try raw.print("{d} ms." ++ tty.E.CURSOR_DOWN, .{(elapsed) / std.time.ns_per_ms});
}

/// Circle test
pub fn test_circle(plot: *plotter.Plotter, raw: tty.RawMode) !void {
    var timer = try std.time.Timer.start();
    try draw.circle(plot, raw, 20, 50, 30);
    try draw.circle(plot, raw, 5, 40, 36);
    try draw.circle(plot, raw, 3, 60, 32);
    try draw.curve(
        plot,
        .{ .x = 42, .y = 12 },
        .{ .x = 46, .y = 8 },
        .{ .x = 58, .y = 12 },
    );
    try draw.coords(plot, raw);
    const elapsed: f32 = @floatFromInt(timer.lap());
    try raw.goto(0, 0);
    try raw.print("{d} ms.", .{(elapsed) / std.time.ns_per_ms});
}
