/// A set of drawing routines to terminal
const std = @import("std");
const tty = @import("tty.zig");
const braille = @import("braille.zig");
const E = tty.E;

pub const Point = struct { x: f32, y: f32 };

/// Drawing a circle in 2d can be defined by two variables:
///    - origin: an (x, y) point on the plane
///    - r: the desired radius of the circle
///
/// Then, stepping from t=[0, 2pi] the circle is then defined by
///     c = origin + (r * cos(t), r * sin(t))
pub fn circle(allocator: std.mem.Allocator, raw: tty.RawMode, r: f32, ox: f32, oy: f32) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();

    const tmax = 2 * std.math.pi;
    const tstep = 0.02;
    var t: f32 = 0;

    // draw circle
    while (t < tmax + 0.1) : (t += tstep) {
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
        try raw.write(E.GOTO ++ E.CLEAR_LINE, .{ 0, 0 });
        try raw.write("{d}x{d} | ({d:.2}, {d:.2}) ({}+{d:.1}, {}+{d:.1}) {s}", .{
            raw.width, raw.height,
            x,         y,
            plotx,     bx,
            ploty,     by,
            bbit,
        });
        try raw.goto(plotx, ploty);
        _ = try raw.tty.write(&bbit);
        // Slight delay to see drawing!
        // std.time.sleep(std.time.ns_per_ms);
    }
}

pub fn coords(allocator: std.mem.Allocator, raw: tty.RawMode) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    for (0..raw.height - 1) |i| {
        try raw.goto(0, i);
        const char = try plt.plot(0, @floatFromInt(i));
        _ = try raw.tty.write(&char);
    }
    for (0..raw.width) |i| {
        try raw.goto(i, 0);
        _ = try plt.plot(@floatFromInt(i), 0);
        const char = try plt.plot(@as(f32, @floatFromInt(i)) + 0.6, 0);
        _ = try raw.tty.write(&char);
    }
}

pub fn sin(allocator: std.mem.Allocator, raw: tty.RawMode, shift: f32) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    var x: f32 = 0.0;
    // Clear the lines before rendering
    for (1..5) |y| {
        try raw.goto(0, y);
        try raw.write(E.CLEAR_LINE, .{});
    }
    try raw.write(E.SET_ANSI_FG, .{2});
    while (x < @as(f32, @floatFromInt(raw.width))) : (x += 0.1) {
        const y = @sin(x + shift) * 2 + 3.0;
        const c = try plt.plot(x, y);
        try raw.goto(@intFromFloat(x), @intFromFloat(y));
        _ = try raw.tty.write(&c);
    }

    const end: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.goto(24, 0);
    try raw.write("{d} ms.", .{(end - start) / std.time.ns_per_ms});
}

/// TODO:
/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn torus(allocator: std.mem.Allocator, raw: tty.RawMode, a: f32, b: f32) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
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
        //       x           y       z    [ -sin(p)  0  cos(p) ]
        //
        // => (x*cos(p)-(z*sin(p)), y, x*sin(p)+z*cos(p))
        // Then we just repeat this for the other [rotation matrices](https://en.wikipedia.org/wiki/Rotation_matrix#General_3D_rotations)
    }
    const k1 = 15.0;
    const k2 = 5.0;
    const r1 = 1.0;
    const r2 = 3.0;
    var t: f32 = 0.0;
    try raw.write(E.CLEAR_SCREEN, .{});
    while (t < 2 * std.math.pi) : (t += 0.3) {
        var p: f32 = 0;
        while (p < 2 * std.math.pi) : (p += 0.2) {
            // So first, a circle.
            const cx: f32 = r2 + r1 * @cos(t);
            const cy: f32 = (r1 * @sin(t));
            const cz: f32 = 0;
            // Then apply the rotation to form the torus and movement

            var x = cx;
            var y = cy;
            var z = cz;
            // y-axis
            {
                const next = .{
                    // zig fmt: off
                    .x =  x*@cos(p) + 0 + z*@sin(p),
                    .y =       0    + y +     0,
                    .z = -x*@sin(p) + 0 + z*@cos(p),
                    // zig fmt: on
                };
                x = next.x;
                y = next.y;
                z = next.z;
            }
            // x-axis
            {
                const next = .{
                    // zig fmt: off
                    .x = x +     0      +    0,
                    .y = 0 + y*@cos(a) + z*@sin(a),
                    .z = 0 - y*@sin(a) + z*@cos(a),
                    // zig fmt: on
                };
                x = next.x;
                y = next.y;
                z = next.z;
            }
            // z-axis
            {
                const next = .{
                    // zig fmt: off
                    .x =  x*@cos(b) + y*@sin(b) + 0,
                    .y = -x*@sin(b) + y*@cos(b) + 0,
                    .z =      0     +     0     + z,
                    // zig fmt: on
                };
                x = next.x;
                y = next.y;
                z = next.z;
            }
            // zig fmt: on
            // var x = cx * (@cos(b) * @cos(p) + @sin(a) * @sin(b) * @sin(p)) - (cy * @cos(a) * @cos(b));
            // var y = cx * (@sin(b) * @cos(p) - @sin(a) * @cos(b) * @sin(p)) + (cy * @cos(a) * @cos(b));
            // z = k2 + (@cos(a) * cx * @sin(p)) + (cy * @sin(a));
            x = (k1 * x) / (z + k2);
            y = (k1 * y) / (z + k2) / 2;
            if ((x + 30) < 0 or (y + 15) < 0) {
                try raw.write(E.GOTO ++ E.CLEAR_LINE, .{ 0, 0 });
                try raw.write("WASGONNA CRASH: {d}x{d} | ({d:.2}, {d:.2}, {d:.2})", .{
                    raw.width, raw.height,
                    x,         y,
                    z,
                });
                return;
            }
            const plotx: u16 = @intFromFloat(@trunc(x + 30));
            const ploty: u16 = @intFromFloat(@trunc(y + 15));
            try raw.write(E.GOTO ++ E.CLEAR_LINE, .{ 0, 0 });
            try raw.write("{d}x{d} | t={d:.2}, p={d:.2} ({d:.2}, {d:.2}, {d:.2}) ({}, {})", .{
                raw.width, raw.height,
                t,         p,
                x,         y,
                z,         plotx,
                ploty,
            });
            const char = try plt.plot(x, y);
            try raw.goto(plotx, ploty);
            _ = try raw.tty.write(&char);
        }
    }
}

pub fn curve(allocator: std.mem.Allocator, raw: tty.RawMode, p0: Point, p1: Point, p2: Point) !void {
    var plt = braille.Plotter.init(allocator, raw);
    defer plt.deinit();
    var t: f32 = 0;
    while (t < 1.0) : (t += 0.01) {
        const ax = lerp(t, p0.x, p1.x);
        const ay = lerp(t, p0.y, p1.y);
        const bx = lerp(t, p1.x, p2.x);
        const by = lerp(t, p1.y, p2.y);
        const cx = lerp(t, ax, bx);
        const cy = lerp(t, ay, by);
        const char = try plt.plot(cx, cy);
        const plotx: u16 = @intFromFloat(@trunc(cx));
        const ploty: u16 = @intFromFloat(@trunc(cy));
        try raw.goto(plotx, ploty);
        _ = try raw.tty.write(&char);
    }
}

/// lerp does a linear interpolation
fn lerp(t: f32, x1: f32, x2: f32) f32 {
    return (x1 * t) + x2 * (1 - t);
}
