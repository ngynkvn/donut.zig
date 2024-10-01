const std = @import("std");

const posix = std.posix;
const system = std.posix.system;

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const plotter = @import("plotter.zig");
const braille = @import("braille.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
const allocator = gpa.allocator();

pub fn main() !void {
    const ttyh = try std.fs.openFileAbsolute(tty.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close();

    const raw = try tty.RawMode.enable(ttyh);
    defer {
        const errno = raw.restore() catch @panic("failed to write :(");
        std.debug.print("{}\n", .{gpa.deinit()});
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }
    var plot = braille.Plotter.init(allocator, raw);
    defer plot.deinit();
    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    {
        const start = try std.time.Instant.now();
        try draw.circle(&plot, raw, 20, 50, 30);
        try draw.circle(&plot, raw, 5, 40, 36);
        try draw.circle(&plot, raw, 3, 60, 32);
        try draw.curve(
            &plot,
            .{ .x = 42, .y = 12 },
            .{ .x = 46, .y = 8 },
            .{ .x = 58, .y = 12 },
        );
        try draw.coords(&plot, raw);
        const elapsed: f32 = @floatFromInt((try std.time.Instant.now()).since(start));
        try raw.goto(0, 0);
        try raw.write("{d} ms.", .{(elapsed) / std.time.ns_per_ms});
    }

    var a: f32 = 0.0;
    var b: f32 = 0.0;
    var buffer: [128]u8 = undefined;
    try raw.write(E.SET_ANSI_FG, .{2});
    {
        while (raw.read(&buffer) catch null) |n| {
            const start = try std.time.Instant.now();
            if (std.mem.eql(u8, buffer[0..n], "\r")) {
                return;
            }
            if (std.mem.eql(u8, buffer[0..n], "\x03")) { // <C-c>
                return;
            }
            _ = try raw.tty.write(buffer[0..n]);
            try draw.torus(&plot, raw, a, b);
            try raw.goto(0, 1);
            const elapsed: f32 = @floatFromInt((try std.time.Instant.now()).since(start));
            try raw.write("{d} ms", .{elapsed / std.time.ns_per_ms});
            a += 0.05;
            b += 0.02;
        }
    }
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
