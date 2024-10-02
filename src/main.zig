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

/// Run a bunch of test routines, continuing to next when 'Enter' is pressed.
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
    var plot = plotter.Plotter{ .braille = @constCast(&braille.Plotter.init(allocator, raw)) };
    defer plot.deinit();

    // Line test
    {
        const rw: f32 = @floatFromInt(raw.width);
        const rh: f32 = @floatFromInt(raw.height);
        var timer = try std.time.Timer.start();
        try draw.line(&plot, .{ .x = 0, .y = rh - 0.1 }, .{ .x = rw, .y = rh - 0.1 });
        try draw.line(&plot, .{ .x = 0, .y = rh - 1 }, .{ .x = rw, .y = rh - 1 });
        try draw.line(&plot, .{ .x = 0, .y = rh - 2 }, .{ .x = rw, .y = rh - 2 });
        try raw.goto(0, raw.height);
        try raw.printTermSize();
        const elapsed: f32 = @floatFromInt(timer.lap());
        try draw.box(raw, .{ .x = 5, .y = rh - 5 }, .{ .x = 10, .y = rh - 10 }, true);
        try raw.goto(0, 0);
        try raw.print("{d} ms.", .{(elapsed) / std.time.ns_per_ms});
    }
    std.Thread.sleep(std.time.ns_per_s * 10);
    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    {
        var timer = try std.time.Timer.start();
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
        const elapsed: f32 = @floatFromInt(timer.lap());
        try raw.goto(0, 0);
        try raw.print("{d} ms.", .{(elapsed) / std.time.ns_per_ms});
    }

    {
        var a: f32 = 0.0;
        var b: f32 = 0.0;
        var buffer: [128]u8 = undefined;
        var frame_times: [32]u64 = .{0} ** 32;
        var frame: usize = 0;
        try raw.print(E.SET_ANSI_FG ++ E.CLEAR_SCREEN, .{2});
        var timer_read = try std.time.Timer.start();
        var timer_frame = try std.time.Timer.start();
        while (true) {
            if (timer_read.read() > std.time.ns_per_ms * 100) {
                const n = try raw.read(&buffer);
                if (std.mem.eql(u8, buffer[0..n], "\r")) {
                    return;
                }
                if (std.mem.eql(u8, buffer[0..n], "\x03")) { // <C-c>
                    return;
                }
            }
            try draw.torus(&plot, raw, a, b);
            try draw.line(&plot, .{ .x = 0, .y = @floatFromInt(raw.height - 5) }, .{ .x = 36, .y = @floatFromInt(raw.height - 5) });
            try raw.goto(0, raw.height - 4);
            a += 0.05;
            b += 0.02;
            const elapsed: u64 = timer_frame.lap();
            frame_times[frame] = elapsed;
            frame = (frame + 1) % 32;

            var sum: f32 = 0;
            for (frame_times) |t| {
                sum += (@as(f32, @floatFromInt(t)) / 32);
            }
            try raw.print("avg     {d:<4.2}ms", .{sum / std.time.ns_per_ms});
            std.Thread.sleep(16 * std.time.ns_per_ms);
        }
    }
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
pub const Panic = @import("panic.zig");
