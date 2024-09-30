/// A set of drawing routines to terminal
const std = @import("std");
const tty = @import("tty.zig");
const braille = @import("braille.zig");
const E = tty.E;

/// Drawing a circle in 2d can be defined by two variables:
///    - origin: an (x, y) point on the plane
///    - r: the desired radius of the circle
///
/// Then, stepping from t=[0, 2pi] the circle is then defined by
///     c = origin + (r * cos(t), r * sin(t))
pub fn circle(allocator: std.mem.Allocator, raw: tty.RawMode) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    // radius of circle
    const r = 20.0;
    // origin
    const ox = 50;
    const oy = 30;

    const maxt = 2 * std.math.pi;
    const tstep = 0.02;
    var t: f32 = 0;

    try raw.write(E.GOTO, .{ 0, 0 });
    try raw.write(E.CLEAR_SCREEN, .{});
    // draw circle
    while (t < maxt + 0.1) : (t += tstep) {
        const x = (ox + r * @cos(t));
        const y = (oy + r * @sin(t)) / 2;
        const plotx: u16 = @intFromFloat(@trunc(x));
        const ploty: u16 = @intFromFloat(@trunc(y));

        const subx = @mod(x, 1);
        const bx = @trunc(subx * 2);
        const suby = @mod(y, 1);
        // Convert 0.0 - 1.0 to 0 - 3
        const by = @trunc(suby * 4);

        const bbit = try plt.plot(x, y);
        try raw.write(E.GOTO, .{ 0, 0 });
        try raw.write(E.CLEAR_LINE, .{});
        // zig fmt: off
        try raw.write("{d}x{d} | ({d:.2}, {d:.2}) ({}+{d:.1}, {}+{d:.1}) {s}", .{
            raw.width, raw.height,
            x, y,
            plotx, bx, ploty, by,
            bbit,
        });
        // zig fmt: on
        try raw.goto(plotx, ploty);
        try raw.write("{s}", .{bbit});
        // Slight delay to see drawing!
        std.time.sleep(std.time.ns_per_ms);
    }
}

pub fn coords(allocator: std.mem.Allocator, raw: tty.RawMode) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    for (0..raw.height - 1) |i| {
        try raw.goto(0, i);
        const char = try plt.plot(0, @floatFromInt(i));
        try raw.write("{s}", .{char});
    }
    for (0..raw.width) |i| {
        try raw.goto(i, 0);
        _ = try plt.plot(@floatFromInt(i), 0);
        const char = try plt.plot(@as(f32, @floatFromInt(i)) + 0.6, 0);
        try raw.write("{s}", .{char});
    }
}

pub fn sin(allocator: std.mem.Allocator, raw: tty.RawMode, shift: f32) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    var x: f32 = 0.0;
    // Clear the lines before rendering
    for (8..12) |y| {
        try raw.goto(0, y);
        try raw.write(E.CLEAR_LINE, .{});
    }
    try raw.write(E.SET_ANSI_FG, .{2});
    while (x < @as(f32, @floatFromInt(raw.width))) : (x += 0.1) {
        const y = @sin(x + shift) * 2 + 10.0;
        const c = try plt.plot(x, y);
        try raw.goto(@intFromFloat(x), @intFromFloat(y));
        try raw.write("{s}", .{c});
    }

    const end: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.goto(24, 0);
    try raw.write("{d} ms.", .{(end - start) / std.time.ns_per_ms});
}

/// TODO:
/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn torus(_: tty.RawMode) !void {
    { // INFO:
        //
        // To render a 3d object onto a 2d screen,
        // you project the (x, y, z) in 3d space so
        // that the corresponding 2D position is (x', y')
        //
        // screen position (x', y') is proportional to
        // the 3d position, the projection works out to
        // y'/z' = y/z
        // y' = (yz')/z
        // Setting z to some fixed constant k since donut will not move
    }
    const k = 5.0;
    _ = k; // autofix

    { // INFO:
        //
        // How do we draw a torus?
        // A torus is just a circle that is
        // swept around an axis to form a solid object.
        // so you need:
        //  - R1:  Circle Radius
        //  - R2:  Inner Radius (Point to sweep around)
        //  - t:   theta, 0-2pi for rotating around axis
        //  - p:   phi, 0-2pi for rotating
        //  2-D circle drawn in 3d space:
        //  - (x,y,z) = (R2, 0, 0) + (R1cos(t), R1sin(t), 0)
        //  - [sweeping a line around z]
        //  Rotate circle in y-axis:
        //
        //                                [  cos(p)  0  sin(p) ]
        // (R2 + R1cos(t), R1sin(t), 0) * [    0     1     0   ]
        //                                [ -sin(p)  0  cos(p) ]
    }
}

/// lerp does a linear interpolation
fn lerp(t: f32, x1: f32, x2: f32) f32 {
    return (x1 * t) + x2 * (1 - t);
}
