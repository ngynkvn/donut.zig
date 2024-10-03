const std = @import("std");
const tty = @import("tty.zig");

// TODO: does the plotter have to know about 3d?..
// Plotter allows for drawing to a terminal using braille characters.
pub const Plotter = struct {
    const Key = struct { i16, i16 };
    raw: tty.RawMode,
    buffer: std.AutoHashMap(Key, u8),
    pub fn init(allocator: std.mem.Allocator, raw: tty.RawMode) Plotter {
        return Plotter{ .raw = raw, .buffer = std.AutoHashMap(Key, u8).init(allocator) };
    }
    pub fn deinit(self: *Plotter) void {
        self.buffer.deinit();
    }

    pub fn clear(self: *Plotter) void {
        self.buffer.clearRetainingCapacity();
    }

    pub const Components = packed struct(u32) { x: i12, sx: i4, y: i12, sy: i4 };
    // Returns the key of x, y packed as a u64
    pub fn components(x: f32, y: f32) Components {
        const plotx: i12 = @intFromFloat(@trunc(x));
        const ploty: i12 = @intFromFloat(@trunc(y));
        const sx = @trunc(@mod(x, 1) * 2);
        const sy = @trunc(@mod(y, 1) * 4);
        return Components{ .x = plotx, .sx = @intFromFloat(sx), .y = ploty, .sy = @intFromFloat(sy) };
    }
    pub fn get(self: *Plotter, x: f32, y: f32) ?[3]u8 {
        const key = Key{ @intFromFloat(x), @intFromFloat(y) };
        if (self.buffer.get(key)) |entry| {
            return BraillePoint(entry.value_ptr.*);
        } else return null;
    }

    pub fn plot(self: *Plotter, x: f32, y: f32) !void {
        const key = Key{ @intFromFloat(x), @intFromFloat(y) };
        const sx = @trunc(@mod(x, 1) * 2);
        const sy = @trunc(@mod(y, 1) * 4);
        const result = try self.buffer.getOrPutValue(key, 0);
        result.value_ptr.* = set_bbit(result.value_ptr.*, @intFromFloat(sx), @intFromFloat(sy));
        const plotx: u16 = @intFromFloat(@trunc(x));
        const ploty: u16 = @intFromFloat(@trunc(y));
        try self.raw.print(tty.E.GOTO ++ "{s}", .{ self.raw.height - ploty, plotx, BraillePoint(result.value_ptr.*) });
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
///    0 3 -> 03 13 | 000 011
///    1 4 -> 02 12 | 001 100
///    2 5 -> 01 11 | 010 101
///    6 7 -> 00 10 | 110 111
pub fn set_bbit(braille_bit: u8, xi: u1, yi: u2) u8 {
    const mask: u3 = ~(yi | yi >> 1) & 1;
    const x = @as(u3, xi);
    const y = @as(u3, yi);
    const pos = (y ^ 3) + x * 3 + (mask | mask << (~xi & 1));
    return braille_bit | (@as(u8, 1) << @truncate(pos));
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
            set_bbit(0, 0, 0),
        );
        try std.testing.expectEqual(
            0b1000_0000,
            set_bbit(0, 1, 0),
        );
        try std.testing.expectEqual(
            0b0100_0000,
            set_bbit(0, 0, 0),
        );
        try std.testing.expectEqual(
            0b0000_1000,
            set_bbit(0, 1, 3),
        );
    }
}
