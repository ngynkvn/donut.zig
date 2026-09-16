const std = @import("std");
const tty = @import("tty.zig");

const CONFIG = .{
    .MARK_EDGES = false,
    .TRACING = true,
};

pub var ncalls: usize = 0;
pub var nfresh: usize = 0;
pub var nredraws: usize = 0;

// TODO: does the plotter have to know about 3d?..
/// Plotter allows for drawing to a terminal using braille characters.
pub const Plotter = struct {
    const Key = struct { u16, u16 };
    raw: *tty.RawMode,
    buffer: std.AutoHashMap(Key, u8),
    width: f32 = 0,
    height: f32 = 0,
    pub fn init(allocator: std.mem.Allocator, raw: *tty.RawMode) Plotter {
        return Plotter{
            .raw = raw,
            .buffer = std.AutoHashMap(Key, u8).init(allocator),
            .width = @floatFromInt(raw.width),
            .height = @floatFromInt(raw.height),
        };
    }
    pub fn deinit(self: *Plotter) void {
        self.buffer.deinit();
    }

    pub fn clear(self: *Plotter) void {
        self.buffer.clearRetainingCapacity();
    }

    fn contains(self: *const Plotter, x: f32, y: f32) bool {
        // Check before integer conversion; this also rejects NaN and infinity.
        return x >= 0 and x < self.width and y >= 0 and y < self.height;
    }

    pub fn erase(self: *Plotter, x: f32, y: f32) !void {
        if (!self.contains(x, y)) return;
        const key = Key{ @intFromFloat(x), @intFromFloat(y) };
        const sx = @trunc(@mod(x, 1) * 2);
        const sy = @trunc(@mod(y, 1) * 4);
        const result = try self.buffer.getOrPutValue(key, 0);
        result.value_ptr.* = unsetBbit(result.value_ptr.*, @intFromFloat(sx), @intFromFloat(sy));
        const plotx: u16 = @intFromFloat(x);
        const ploty: u16 = @intFromFloat(y);
        try self.raw.print(tty.E.GOTO ++ " ", .{ self.raw.height - ploty, plotx });
    }

    pub fn plot(self: *Plotter, x: f32, y: f32) !void {
        if (!self.contains(x, y)) return;
        // NOTE: explore vectors
        const ux: u16 = @intFromFloat(x);
        const uy: u16 = @intFromFloat(y);
        const key = Key{ ux, uy };
        const sx = (x - @trunc(x)) * 2;
        const sy = (y - @trunc(y)) * 4;

        const result = try self.buffer.getOrPutValue(key, 0);
        const bbit = result.value_ptr.*;
        const newbit = setBbit(bbit, @intFromFloat(sx), @intFromFloat(sy));
        if (CONFIG.TRACING) {
            ncalls += 1;
            if (bbit != newbit) nfresh += 1 else nredraws += 1;
        }
        if (bbit == newbit) return;

        result.value_ptr.* = setBbit(bbit, @intFromFloat(sx), @intFromFloat(sy));
        try self.raw.print(tty.E.GOTO ++ "{s}", .{ self.raw.height - uy, ux, BraillePoint(result.value_ptr.*) });

        if (CONFIG.MARK_EDGES) {
            try self.raw.print(tty.E.GOTO ++ "{s}", .{ self.raw.height - uy, 0, BraillePoint(result.value_ptr.*) });
            try self.raw.print(tty.E.GOTO ++ "{s}", .{ 0, ux, BraillePoint(result.value_ptr.*) });
        }
    }
};

///The Braille unicode range is #x2800 - #x28FF, where each dot is one of 8 bits
///    Because Braille was originally only 6 dots, the order of bits is:
///    1 4
///    2 5
///    3 6
///    7 8
pub const BRAILLE_TABLE: [256][3]u8 = ret: {
    const BRAILLE_START_CODEPOINT = 0x2800;
    var gen: [256][3]u8 = undefined;
    for (0..0x100) |value| {
        // TODO: Checkout why this is needed
        @setEvalBranchQuota(256 * 10);
        const bytes = std.unicode.utf8EncodeComptime(BRAILLE_START_CODEPOINT + value);
        gen[value] = bytes;
    }
    break :ret gen;
};

///Set a u8 representing a braille code as a bitmap
///    |  i  |  xy   |   u8    |
///    | :-: | :---: | :-----: |
///    | 0 3 | 03 13 | 000 011 |
///    | 1 4 | 02 12 | 001 100 |
///    | 2 5 | 01 11 | 010 101 |
///    | 6 7 | 00 10 | 110 111 |
pub fn setBbit(braille_bit: u8, xi: u1, yi: u2) u8 {
    const mask: u3 = ~(yi | yi >> 1) & 1;
    const x = @as(u3, xi);
    const y = @as(u3, yi);
    const pos = (y ^ 3) + x * 3 + (mask | mask << (~xi & 1));
    return braille_bit | (@as(u8, 1) << @truncate(pos));
}
pub fn unsetBbit(braille_bit: u8, xi: u1, yi: u2) u8 {
    const mask: u3 = ~(yi | yi >> 1) & 1;
    const x = @as(u3, xi);
    const y = @as(u3, yi);
    const pos = (y ^ 3) + x * 3 + (mask | mask << (~xi & 1));
    return ~braille_bit & (@as(u8, 1) << @truncate(pos));
}

pub fn BraillePoint(point: u8) [3]u8 {
    return BRAILLE_TABLE[point];
}

test "braille accessor" {
    {
        const p = BraillePoint(0xff);
        try std.testing.expectEqual(BRAILLE_TABLE[255], p);
    }
    {
        try std.testing.expectEqual(
            0b0100_0000,
            setBbit(0, 0, 0),
        );
        try std.testing.expectEqual(
            0b1000_0000,
            setBbit(0, 1, 0),
        );
        try std.testing.expectEqual(
            0b0100_0000,
            setBbit(0, 0, 0),
        );
        try std.testing.expectEqual(
            0b0000_1000,
            setBbit(0, 1, 3),
        );
    }
}

test "plotter clips off-screen and non-finite coordinates" {
    var raw: tty.RawMode = .{
        .orig_termios = undefined,
        .tty = undefined,
        .io = std.testing.io,
        .width = 80,
        .height = 24,
        .buffer = std.Io.Writer.Allocating.init(std.testing.allocator),
    };
    defer raw.buffer.deinit();
    var plotter = Plotter.init(std.testing.allocator, &raw);
    defer plotter.deinit();

    for ([_][2]f32{
        .{ 40, -0.5 },              .{ -0.5, 12 },               .{ 80, 12 },                .{ 40, 24 },
        .{ 40, -100000 },           .{ 100000, 12 },             .{ std.math.nan(f32), 12 }, .{ 40, std.math.nan(f32) },
        .{ std.math.inf(f32), 12 }, .{ 40, -std.math.inf(f32) },
    }) |point| {
        try plotter.plot(point[0], point[1]);
        try plotter.erase(point[0], point[1]);
    }
    try std.testing.expectEqual(@as(u32, 0), plotter.buffer.count());
    try std.testing.expectEqual(@as(usize, 0), raw.buffer.written().len);

    try plotter.plot(0, 0);
    try plotter.plot(79.5, 23.75);
    try std.testing.expectEqual(setBbit(0, 0, 0), plotter.buffer.get(.{ 0, 0 }).?);
    try std.testing.expectEqual(setBbit(0, 1, 3), plotter.buffer.get(.{ 79, 23 }).?);
}
