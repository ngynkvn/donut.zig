/// A set of drawing routines to terminal
const std = @import("std");
const tty = @import("tty.zig");
const braille = @import("braille.zig");
const plotter = @import("plotter.zig");
const E = tty.E;

/// Drawing a circle in 2d can be defined by two variables:
///    - origin: an (x, y) point on the plane
///    - r: the desired radius of the circle
///
/// Then, stepping from t=[0, 2pi] the circle is then defined by
///     c = origin + (r * cos(t), r * sin(t))
pub fn circle(plt: *plotter.Plotter, raw: tty.RawMode, r: f16, ox: f16, oy: f16) !void {
    const tmax = 2 * std.math.pi;
    const tstep = 0.02;
    var t: f16 = 0;

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

        try plt.plot(x, y);
        try raw.write(E.GOTO ++ E.CLEAR_LINE, .{ 0, 0 });
        try raw.write("{d}x{d} | ({d:.2}, {d:.2}) ({}+{d:.1}, {}+{d:.1})", .{
            raw.width, raw.height,
            x,         y,
            plotx,     bx,
            ploty,     by,
        });
        // Slight delay to see drawing!
        //std.time.sleep(std.time.ns_per_ms);
    }
}

pub fn coords(plt: *plotter.Plotter, raw: tty.RawMode) !void {
    for (0..raw.height - 1) |i| {
        try raw.goto(0, i);
        try plt.plot(0, @floatFromInt(i));
    }
    for (0..raw.width) |i| {
        try raw.goto(i, 0);
        try plt.plot(@floatFromInt(i), 0);
        try plt.plot(@as(f16, @floatFromInt(i)) + 0.6, 0);
    }
}

pub fn sin(plt: *plotter.Plotter, raw: tty.RawMode, shift: f16) !void {
    const start = try std.time.Instant.now();
    var x: f16 = 0.0;
    // Clear the lines before rendering
    for (1..5) |y| {
        try raw.goto(0, y);
        try raw.write(E.CLEAR_LINE, .{});
    }
    try raw.write(E.SET_ANSI_FG, .{2});
    while (x < @as(f16, @floatFromInt(raw.width))) : (x += 0.1) {
        const y = @sin(x + shift) * 2 + 3.0;
        const c = try plt.plot(x, y);
        try raw.goto(@intFromFloat(x), @intFromFloat(y));
        _ = try raw.tty.write(&c);
    }

    const elapsed: f32 = @floatFromInt((try std.time.Instant.now()).since(start));
    try raw.goto(24, 0);
    try raw.write("{d} ms.", .{elapsed / std.time.ns_per_ms});
}

/// TODO:
/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn torus(plt: *plotter.Plotter, raw: tty.RawMode, a: f16, b: f16) !void {
    plt.clear();
    try raw.goto(0, raw.height - 6);
    try raw.write(E.CLEAR_DOWN, .{});

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

    const k1 = 8.0;
    const k2 = 5.0;
    const r1 = 1.0;
    const r2 = 3.0;
    var t: f16 = 0.0;
    while (t < 2 * std.math.pi) : (t += 0.3) {
        var p: f16 = 0;
        while (p < 2 * std.math.pi) : (p += 0.2) {
            // So first, a circle.
            const cx: f16 = r2 + r1 * @cos(t);
            const cy: f16 = (r1 * @sin(t));
            // Then apply the rotation to form the torus and movement
            // zig fmt: off
            const sina: f16 = @sin(a); const sinb: f16 = @sin(b); const sinp: f16 = @sin(p);
            const cosa: f16 = @cos(a); const cosb: f16 = @cos(b); const cosp: f16 = @cos(p);
            // zig fmt: on
            var x = cx * (cosb * cosp + sina * sinb * sinp) - (cy * cosa * sinb);
            var y = cx * (cosp * sinb - cosb * sina * sinp) + (cy * cosa * cosb);
            const z = cosa * cx * sinp + (cy * sina);
            x = (k1 * 2 * x) / (z + k2);
            y = (k1 * y) / (z + k2);
            const plotx = x + @as(f16, @floatFromInt(raw.width)) / 2;
            const ploty = y + @as(f16, @floatFromInt(raw.height - 5)) / 2;
            try raw.write(E.HOME, .{});
            try raw.write( //
                "{d}x{d} | t={d:>4.2}, p={d:>4.2}\r\n" ++
                "({d:>6.2},{d:>6.2},{d:>6.2})\r\n" ++
                "({d:>6.2},{d:>6.2})", .{
                raw.width, raw.height, t, p, x, y, z, plotx, ploty,
            });
            try plt.plot(plotx, ploty);
        }
    }
}

const M = @This();

pub const Point = struct {
    x: f16,
    y: f16,
    pub fn lerp(p1: Point, t: f16, p2: Point) Point {
        return Point{
            .x = M.lerp(t, p1.x, p2.x),
            .y = M.lerp(t, p1.y, p2.y),
        };
    }
};
// zig fmt: off
const horiz    = std.unicode.utf8EncodeComptime(0x2500);
const vert     = std.unicode.utf8EncodeComptime(0x2502);
const cornerdr = std.unicode.utf8EncodeComptime(0x250C);
const cornerdl = std.unicode.utf8EncodeComptime(0x2510);
const cornerur = std.unicode.utf8EncodeComptime(0x2514);
const cornerul = std.unicode.utf8EncodeComptime(0x2518);
// zig fmt: on
comptime {
    if (false)
        @compileError(&horiz ++ vert ++ " " ++ cornerdr ++ cornerdl ++ " " ++ cornerur ++ cornerul);
}

/// top left corner, bottom right corner
pub fn box(raw: tty.RawMode, ptl: Point, pbr: Point) !void {
    const x0: u16 = @intFromFloat(if (ptl.x < pbr.x) ptl.x else pbr.x);
    const x1: u16 = @intFromFloat(if (ptl.x < pbr.x) pbr.x else ptl.x);
    const y0: u16 = @intFromFloat(if (ptl.y < pbr.y) ptl.y else pbr.y);
    const y1: u16 = @intFromFloat(if (ptl.y < pbr.y) pbr.y else ptl.y);
    for (x0..x1) |w| {
        try raw.goto(w, y0);
        _ = try raw.tty.write(&horiz);
        try raw.goto(w, y1);
        _ = try raw.tty.write(&horiz);
    }
    for (y0..y1) |h| {
        try raw.goto(x0, h);
        _ = try raw.tty.write(&vert);
        try raw.goto(x1, h);
        _ = try raw.tty.write(&vert);
    }
}

pub fn curve(plt: *plotter.Plotter, p0: Point, p1: Point, p2: Point) !void {
    var t: f16 = 0;
    while (t < 1.0) : (t += 0.01) {
        const a = p0.lerp(t, p1);
        const b = p1.lerp(t, p2);
        const c = a.lerp(t, b);
        try plt.plot(c.x, c.y);
    }
}

/// lerp does a linear interpolation
pub fn lerp(t: f16, x1: f16, x2: f16) f16 {
    return (x1 * t) + x2 * (1 - t);
}
