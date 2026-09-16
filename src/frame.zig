const std = @import("std");
const tty = @import("tty.zig");
const braille = @import("braille.zig");

/// Dense, reusable braille buffers. The top seven rows belong to diagnostics.
pub const Frame = struct {
    pub const Cell = struct {
        bits: u8 = 0,
        color: u8 = 0,

        fn eql(a: Cell, b: Cell) bool {
            return a.bits == b.bits and a.color == b.color;
        }
    };

    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
    current: []Cell,
    previous: []Cell,
    pub const header_rows = 7;

    pub fn init(allocator: std.mem.Allocator, width: u16, height: u16) !Frame {
        const rows = height -| header_rows;
        const count = @as(usize, width) * rows;
        const current = try allocator.alloc(Cell, count);
        errdefer allocator.free(current);
        const previous = try allocator.alloc(Cell, count);
        @memset(current, .{});
        @memset(previous, .{});
        return .{ .allocator = allocator, .width = width, .height = rows, .current = current, .previous = previous };
    }

    pub fn deinit(self: *Frame) void {
        self.allocator.free(self.current);
        self.allocator.free(self.previous);
    }

    pub fn clear(self: *Frame) void {
        @memset(self.current, .{});
    }

    pub fn plot(self: *Frame, x: f32, y: f32, color: u8) void {
        if (!(x >= 0 and x < @as(f32, @floatFromInt(self.width)) and
            y >= 0 and y < @as(f32, @floatFromInt(self.height)))) return;
        const ix: usize = @intFromFloat(x);
        const iy: usize = @intFromFloat(y);
        const sx: u1 = @intFromFloat((x - @trunc(x)) * 2);
        const sy: u2 = @intFromFloat((y - @trunc(y)) * 4);
        const cell = &self.current[(self.height - 1 - iy) * self.width + ix];
        const bits = braille.setBbit(cell.bits, sx, sy);
        // Match the immediate plotter: the last new dot determines the cell's color.
        if (bits != cell.bits) cell.* = .{ .bits = bits, .color = color };
    }

    /// Emit changed cells once, erasing vacated cells with spaces. Adjacent
    /// changes share a cursor move; equal colors share a color escape sequence.
    pub fn present(self: *Frame, raw: *tty.RawMode) !void {
        var color: ?u8 = null;
        for (0..self.height) |row| {
            var adjacent = false;
            for (0..self.width) |col| {
                const index = row * self.width + col;
                const cell = self.current[index];
                if (cell.eql(self.previous[index])) {
                    adjacent = false;
                    continue;
                }
                if (!adjacent) try raw.gotorc(@intCast(row + header_rows + 1), @intCast(col + 1));
                if (cell.bits == 0) {
                    _ = try raw.write(" ");
                } else {
                    if (color != cell.color) {
                        try raw.print(tty.E.SET_ANSI_FG, .{cell.color});
                        color = cell.color;
                    }
                    _ = try raw.write(&braille.BraillePoint(cell.bits));
                }
                adjacent = true;
            }
        }
        std.mem.swap([]Cell, &self.current, &self.previous);
    }
};

test "frame emits final cells, skips unchanged cells, and erases old dots" {
    var raw: tty.RawMode = .{
        .orig_termios = undefined,
        .tty = undefined,
        .io = std.testing.io,
        .width = 80,
        .height = 24,
        .buffer = std.Io.Writer.Allocating.init(std.testing.allocator),
    };
    defer raw.buffer.deinit();
    var frame = try Frame.init(std.testing.allocator, raw.width, raw.height);
    defer frame.deinit();
    frame.plot(3, 0, 2);
    frame.plot(3.5, 0.75, 2);
    frame.plot(4, 0, 2);
    try frame.present(&raw);
    const bits = comptime braille.setBbit(braille.setBbit(0, 0, 0), 1, 3);
    const expected = "\x1b[24;4H\x1b[32m" ++ braille.BRAILLE_TABLE[bits] ++ braille.BRAILLE_TABLE[braille.setBbit(0, 0, 0)];
    try std.testing.expectEqualStrings(expected, raw.buffer.written());
    raw.buffer.clearRetainingCapacity();
    frame.clear();
    frame.plot(3, 0, 2);
    frame.plot(3.5, 0.75, 2);
    frame.plot(4, 0, 2);
    try frame.present(&raw);
    try std.testing.expectEqual(@as(usize, 0), raw.buffer.written().len);
    frame.clear();
    try frame.present(&raw);
    try std.testing.expectEqualStrings("\x1b[24;4H  ", raw.buffer.written());
}

test "frame clips outside its viewport and redraws color changes" {
    var raw: tty.RawMode = .{
        .orig_termios = undefined,
        .tty = undefined,
        .io = std.testing.io,
        .width = 80,
        .height = 24,
        .buffer = std.Io.Writer.Allocating.init(std.testing.allocator),
    };
    defer raw.buffer.deinit();
    var frame = try Frame.init(std.testing.allocator, raw.width, raw.height);
    defer frame.deinit();
    for ([_][2]f32{ .{ -0.5, 0 }, .{ 0, -0.5 }, .{ 80, 0 }, .{ 0, 17 }, .{ std.math.nan(f32), 0 }, .{ 0, std.math.inf(f32) } }) |p| frame.plot(p[0], p[1], 2);
    try frame.present(&raw);
    try std.testing.expectEqual(@as(usize, 0), raw.buffer.written().len);
    frame.clear();
    frame.plot(0, 16, 2);
    try frame.present(&raw);
    raw.buffer.clearRetainingCapacity();
    frame.clear();
    frame.plot(0, 16, 3);
    try frame.present(&raw);
    try std.testing.expectEqualStrings("\x1b[8;1H\x1b[33m" ++ braille.BRAILLE_TABLE[braille.setBbit(0, 0, 0)], raw.buffer.written());
}
