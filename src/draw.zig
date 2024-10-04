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
pub fn circle(plt: *plotter.Plotter, raw: tty.RawMode, r: f32, ox: f32, oy: f32) !void {
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

        try plt.plot(x, y);
        try raw.print(E.GOTO ++ E.CLEAR_LINE, .{ 0, 0 });
        try raw.print("{d}x{d} | ({d:.2}, {d:.2}) ({}+{d:.1}, {}+{d:.1})", .{
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
        try plt.plot(@as(f32, @floatFromInt(i)) + 0.6, 0);
    }
}

pub fn sin(plt: *plotter.Plotter, raw: tty.RawMode, shift: f32) !void {
    var timer = try std.time.Timer.start();
    var x: f32 = 0.0;
    // Clear the lines before rendering
    for (1..5) |y| {
        try raw.goto(0, y);
        try raw.print(E.CLEAR_LINE, .{});
    }
    try raw.print(E.SET_ANSI_FG, .{2});
    while (x < @as(f32, @floatFromInt(raw.width))) : (x += 0.1) {
        const y = @sin(x + shift) * 2 + 3.0;
        const c = try plt.plot(x, y);
        try raw.goto(@intFromFloat(x), @intFromFloat(y));
        _ = try raw.tty.write(&c);
    }

    const elapsed: f32 = @floatFromInt(timer.lap());
    try raw.goto(24, 0);
    try raw.print("{d} ms.", .{elapsed / std.time.ns_per_ms});
}

/// TODO:
/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn torus(plt: *plotter.Plotter, raw: tty.RawMode, a: f32, b: f32) !void {
    plt.clear();
    try raw.goto(0, raw.height - 6);
    try raw.print(E.CLEAR_DOWN, .{});

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

    // TODO: keymap
    const k1 = 10.0;
    const k2 = 8.0;
    // TODO: keymap
    const r1 = 2.0;
    const r2 = 4.0;

    var npoints: usize = 0;
    npoints = 0;
    var ndraws: usize = 0;
    ndraws = 0;

    var t: f32 = 0.0;
    // TODO: keymap
    while (t < 2 * std.math.pi) : (t += 0.2) {
        var p: f32 = 0;
        const sint: f32 = @sin(t);
        const cost: f32 = @cos(t);
        // TODO: keymap
        std.time.sleep(2999999);
        while (p < 2 * std.math.pi) : (p += 0.2) {
            // So first, a circle.
            const cx: f32 = (r2 + r1 * @cos(t));
            const cy: f32 = r1 * @sin(t);
            // Then apply the rotation to form the torus and movement
            // zig fmt: off
            const sina: f32 = @sin(a); const sinb: f32 = @sin(b); const sinp: f32 = @sin(p); 
            const cosa: f32 = @cos(a); const cosb: f32 = @cos(b); const cosp: f32 = @cos(p); 
            // zig fmt: on
            var x = cx * (cosb * cosp + sina * sinb * sinp) - (cy * cosa * sinb);
            var y = cx * (cosp * sinb - cosb * sina * sinp) + (cy * cosa * cosb);
            const ooz = 1 / (k2 + cosa * cx * sinp + (cy * sina));
            x = (k1 * 2 * x) * ooz;
            y = (k1 * y) * ooz;
            const plotx = x + @as(f32, @floatFromInt(raw.width)) / 2;
            const ploty = y + @as(f32, @floatFromInt(raw.height - 5)) / 2;
            npoints += 1;
            // calculate luminance.  ugly, but correct.
            const L = cosp * cost * sinb - cosa * cost * sinp -
                sina * sint + cosb * (cosa * sint - cost * sina * sinp);

            if (L > 0) {
                try raw.print(E.SET_ANSI_FG, .{1});
            } else {
                try raw.print(E.SET_ANSI_FG, .{3});
            }
            ndraws += 1;
            try plt.plot(plotx, ploty);
            const ux: u16 = @intFromFloat(@mod(x, plt.width));
            const uy: u16 = @intFromFloat(@mod(y, plt.height));
            try raw.print(E.HOME, .{});
            try raw.print( //
                "{d}x{d} | t={d:>4.2}, p={d:>4.2}, a={d:>4}, b={d:>4}\r\n" ++
                "({d:>6.2},{d:>6.2},{d:>6.2})\r\n" ++
                "({d:>6.2},{d:>6.2})", .{
                raw.width, raw.height, t,   p,  a,  b,
                x,         y,          ooz, ux, uy,
            });
        }
    }
    try raw.print("checks: {d:>4}, overlaps: {d:>4}, zbug.size: {d:>4}", .{ npoints, ndraws });
}

const M = @This();

pub const Point = struct {
    x: f32,
    y: f32,
    pub fn lerp(p1: Point, t: f32, p2: Point) Point {
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

pub fn box(raw: tty.RawMode, point_top_left: Point, point_bottom_right: Point, clear_middle: bool) !void {
    const ptl = point_top_left;
    const pbr = point_bottom_right;
    const x0: u16 = @intFromFloat(if (ptl.x < pbr.x) ptl.x else pbr.x);
    const x1: u16 = @intFromFloat(if (ptl.x < pbr.x) pbr.x else ptl.x);
    const y0: u16 = @intFromFloat(if (ptl.y < pbr.y) ptl.y else pbr.y);
    const y1: u16 = @intFromFloat(if (ptl.y < pbr.y) pbr.y else ptl.y);
    for ((x0 + 1)..x1) |x| {
        for ([_]u16{ y0, y1 }) |y| {
            try raw.print(tty.E.GOTO ++ horiz, raw.goto_args(x, y));
        }
    }
    for ((y0 + 1)..y1) |y| {
        for ([_]u16{ x0, x1 }) |x| {
            try raw.print(tty.E.GOTO ++ vert, raw.goto_args(x, y));
        }
    }

    // TODO: I think this is an example of `AoS`,
    // which could be a `SoA` instead, small example tho
    const corners = [4]struct { x: u16, y: u16, c: [3]u8 }{
        .{ .x = x0, .y = y0, .c = cornerur },
        .{ .x = x1, .y = y0, .c = cornerul },
        .{ .x = x1, .y = y1, .c = cornerdl },
        .{ .x = x0, .y = y1, .c = cornerdr },
    };
    for (corners) |cmd| {
        const args = raw.goto_args(cmd.x, cmd.y);
        try raw.print(tty.E.GOTO ++ "{s}", .{ args[0], args[1], cmd.c });
    }
    if (clear_middle) {
        for (y0 + 1..y1 - 1) |y| {
            for (x0 + 1..x1) |x| {
                try raw.print(tty.E.GOTO ++ " ", raw.goto_args(x, y));
            }
        }
    }
}
pub fn line(plt: *plotter.Plotter, a: Point, b: Point) !void {
    for (0..400) |t| {
        const interpolation = a.lerp(@as(f16, @floatFromInt(t)) / 400, b);
        try plt.plot(interpolation.x, interpolation.y);
    }
}

pub fn curve(plt: *plotter.Plotter, p0: Point, p1: Point, p2: Point) !void {
    var t: f32 = 0;
    while (t < 1.0) : (t += 0.01) {
        const a = p0.lerp(t, p1);
        const b = p1.lerp(t, p2);
        const c = a.lerp(t, b);
        try plt.plot(c.x, c.y);
    }
}

/// lerp does a linear interpolation
pub fn lerp(t: f32, x1: f32, x2: f32) f32 {
    return (x1 * t) + x2 * (1 - t);
}
