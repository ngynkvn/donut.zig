const std = @import("std");

const posix = std.posix;
const system = std.posix.system;

const tty = @import("tty.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn main() !void {
    const ttyh = try std.fs.openFileAbsolute(tty.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close();

    const raw = try tty.RawMode.enable(ttyh);
    defer {
        const errno = raw.restore() catch @panic("failed to write :(");
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    try draw_circle(raw);
    try draw_coords(raw);

    const end: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.goto(0, 0);
    try raw.write("{d} ms.", .{(end - start) / std.time.ns_per_ms});

    var buffer: [128]u8 = undefined;
    while (raw.read(&buffer) catch null) |n| {
        for (buffer[0..n]) |c| {
            if (c == '\r') {
                return;
            }
        }
        _ = try raw.tty.write(buffer[0..n]);
    }
}

fn draw_circle(raw: tty.RawMode) !void {
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
    //  - (x,y,z) = (R1, 0, 0) + (R2cos(t), R2sin(t), 0)

    // radius of circle
    const r2 = 20.0;

    const maxt = 2 * std.math.pi;
    const tstep = 0.02;
    var t: f32 = 0;

    try raw.write(E.GOTO, .{ 0, 0 });
    try raw.write(E.CLEAR_SCREEN, .{});
    // draw circle
    var prev_plotx: u16 = 0;
    var prev_ploty: u16 = 0;
    var bbit: u8 = 0;
    while (t < maxt + 0.1) : (t += tstep) {
        const x = (50 + r2 * @cos(t));
        const y = (30 + r2 * @sin(t)) / 2;
        const plotx: u16 = @intFromFloat(@trunc(x));
        const ploty: u16 = @intFromFloat(@trunc(y));

        if (prev_plotx != plotx or prev_ploty != ploty) {
            prev_plotx = plotx;
            prev_ploty = ploty;
            bbit = 0;
        }

        const subx = @mod(x, 1);
        const bx = @trunc(subx * 2);
        const suby = @mod(y, 1);
        // Convert 0.0 - 1.0 to 0 - 3
        const by = @trunc(suby * 4);
        bbit = tty.set_bbit(bbit, @intFromFloat(bx), @intFromFloat(by));

        try raw.write(E.GOTO, .{ 0, 0 });
        try raw.write(E.CLEAR_LINE, .{});
        // zig fmt: off
        try raw.write("{d}x{d}| ({d:.2}, {d:.2}) ({}+{d:.1}, {}+{d:.1}) {s}", .{
            raw.width, raw.height,
            x, y,
            plotx, bx, ploty, by,
            tty.BraillePoint(bbit),
        });
        // zig fmt: on
        try raw.goto(plotx, ploty);
        try raw.write("{s}", .{tty.BraillePoint(bbit)});
        // Slight delay to see drawing!
        std.time.sleep(std.time.ns_per_ms);
    }
}

fn draw_coords(raw: tty.RawMode) !void {
    for (0..raw.height - 1) |i| {
        try raw.goto(0, i);
        try raw.write("*", .{});
    }
    for (0..raw.width) |i| {
        try raw.goto(i, 0);
        try raw.write("-", .{});
    }
}

/// lerp does a linear interpolation
fn lerp(t: f32, x1: f32, x2: f32) f32 {
    return (x1 * t) + x2 * (1 - t);
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
