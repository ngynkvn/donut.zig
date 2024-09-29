const std = @import("std");

const posix = std.posix;
const system = std.posix.system;

const tty = @import("tty.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const luminence = ".,-~:;=!*#$@";

/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn main() !void {
    const ttyh = try std.fs.openFileAbsolute(tty.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close();

    const raw = try tty.RawMode.enable(ttyh);
    defer {
        const errno = raw.restore();
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
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

    //  2-D circle drawn in 3d space:
    //  - (x,y,z) = (R2, 0, 0) + (R1cos(t), R1sin(t), 0)
    const r1 = 40.0;
    const r2 = 100.0;
    const z = 4.0;
    const maxt = 2 * std.math.pi;

    const tstep = 0.05;
    var t: f32 = 0;
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.write(E.CLEAR_SCREEN, .{});
    while (t < maxt + 0.1) : (t += tstep) {
        const x = (r2 + r1 * @cos(t)) / z;
        const y = (r2 + r1 * @sin(t)) / (z * 0.5);
        const xx: u16 = @intFromFloat(@round(x));
        const yy: u16 = @intFromFloat(@round(y));
        const plotx = xx;
        const ploty = yy;
        //std.debug.print("{} {}\n", .{ plotx, ploty });
        try raw.goto(plotx, ploty);
        try raw.write("*", .{});
    }
    _ = try raw.goto(0, 0);
    const end: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.bottom();
    std.debug.print("{d} seconds.", .{(end - start) / std.time.ns_per_s});
}
