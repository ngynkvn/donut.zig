const std = @import("std");
const tty = @import("tty.zig");

const braille = @import("braille.zig");
const setBbit = braille.setBbit;
const BraillePoint = braille.BraillePoint;

const log = std.log.scoped(.raytrace);

pub const Point = @Vector(3, f32);
/// https://raytracing.github.io/books/RayTracingInOneWeekend.html#rays,asimplecamera,andbackground
const CONFIG = .{
    .SPHERE = .{
        .CENTER = Point{ 0.0, 0.0, -5.0 },
        .RADIUS = Point{ 1, 1, 1 },
    },
    .CAMERA = .{
        .EYE = Point{ 0.0, 0.0, 0.0 },
        .LOOK = Point{ 0.0, 0.0, -1.0 },
        .FOCAL_LEN = Point{ 0.0, 0.0, 1.0 },
    },
};

/// Plotter allows for drawing to a terminal using braille characters.
pub const Plotter = struct {
    const Key = struct { usize, usize };
    raw: tty.RawMode,
    buffer: std.AutoHashMap(Key, u8),
    width: usize,
    height: usize,

    vw: f32,
    vh: f32,

    const zmax: f32 = 10;
    comptime {
        // TODO: assert zmax
        std.debug.assert(true);
    }

    pub fn init(allocator: std.mem.Allocator, raw: tty.RawMode) Plotter {
        const vw = 2;
        const vh = 1;
        return Plotter{
            .raw = raw,
            .buffer = std.AutoHashMap(Key, u8).init(allocator),
            .width = raw.width * SCALEX,
            .height = raw.height * SCALEY,
            .vw = vw,
            .vh = vh,
        };
    }
    pub fn deinit(self: *Plotter) void {
        self.buffer.deinit();
    }

    pub fn clear(self: *Plotter) void {
        self.buffer.clearRetainingCapacity();
    }

    fn norm(v: Point) Point {
        const magnitude = @reduce(.Add, v * v);
        return scaled(v, 1 / magnitude);
    }
    pub fn ray(t: f32, O: Point, D: Point) void {
        t = t;
        O = O;
        D = D;
    }

    pub fn plot(self: *Plotter, xscaled: usize, yscaled: usize) !void {
        const x = xscaled / SCALEX;
        const y = yscaled / SCALEY;
        const sx: u1 = @intCast(xscaled % SCALEX);
        const sy: u2 = @intCast(yscaled % SCALEY);
        const key = Key{ x, y };
        const result = try self.buffer.getOrPutValue(key, 0);
        result.value_ptr.* = setBbit(result.value_ptr.*, sx, sy);
        try self.raw.print(tty.E.GOTO ++ "{s}", .{ self.raw.height - y, x, BraillePoint(result.value_ptr.*) });
    }
};

const SCALEX = 2;
const SCALEY = 4;
pub fn sphere(plt: *Plotter, raw: tty.RawMode) !void {
    const vu = Point{ plt.vw, 0, 0 };
    const vv = Point{ 0, -plt.vh, 0 };
    const du = scaled(vu, 1.0 / @as(f32, @floatFromInt(plt.width)));
    const dv = scaled(vv, 1.0 / @as(f32, @floatFromInt(plt.height)));
    //Iterate over subpixels
    for (0..plt.width) |x| {
        const ix: f32 = @floatFromInt(x);
        // NOTE:
        // The offset is to make it so (0, 0) is defined as the middle of our screen
        const offsetx: f32 = @floatFromInt(plt.width / 2);
        const px = scaled(du, ix - offsetx);
        for (0..plt.height) |y| {
            const iy: f32 = @floatFromInt(y);
            const offsety: f32 = @floatFromInt(plt.height / 2);
            const py = scaled(dv, iy - offsety);
            const pixel = px + py;
            const rayDir = pixel - CONFIG.CAMERA.EYE + CONFIG.CAMERA.LOOK;
            const rayOrigin = CONFIG.CAMERA.EYE;
            const origCenter = CONFIG.SPHERE.CENTER - rayOrigin;
            const a = dot(rayDir, rayDir);
            const b = -2 * dot(rayDir, origCenter);
            const c = dot(origCenter, origCenter) - dot(CONFIG.SPHERE.RADIUS, CONFIG.SPHERE.RADIUS);
            const discriminant = b * b - 4 * a * c;
            if (discriminant > 0) {
                try raw.print(tty.E.SET_ANSI_FG, .{2});
                try plt.plot(x, y);
                try raw.print(tty.E.RESET_COLORS, .{});
            }
        }
    }
}

fn scaled(a: Point, scalar_value: f32) Point {
    return a * @as(Point, @splat(scalar_value));
}
fn scalar(s: f32) Point {
    return @splat(s);
}
fn dot(a: Point, b: Point) f32 {
    return @reduce(.Add, a * b);
}
