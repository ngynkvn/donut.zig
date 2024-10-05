const std = @import("std");

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const plotter = @import("plotter.zig");
const braille = @import("braille.zig");
const drawtests = @import("drawtests.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
const allocator = gpa.allocator();

/// Run a bunch of test routines, continuing to next when 'Enter' is pressed.
pub fn main() !void {
    const ttyh = try std.fs.openFileAbsolute(tty.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close();

    var raw = try tty.RawMode.enable(ttyh);
    defer {
        const errno = raw.restore() catch @panic("failed to write :(");
        std.debug.print("{}\n", .{gpa.deinit()});
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }
    var plot = braille.Plotter.init(allocator, raw);
    defer plot.deinit();

    // Line test
    try drawtests.test_line(&plot, raw);

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    try drawtests.test_circle(&plot, raw);

    // Torus test
    {
        var a: f32 = 0.0;
        var b: f32 = -0.4;
        var paused = false;
        var buffer: [128]u8 = undefined;
        var bufferlen: usize = 0;
        var frame_times: [32]u64 = .{0} ** 32;
        var frame: usize = 0;
        var dirty = true;
        try raw.print(E.SET_ANSI_FG ++ E.CLEAR_SCREEN, .{3});
        var timer_read = try std.time.Timer.start();
        var running = true;
        while (running) {
            if (timer_read.read() > std.time.ns_per_ms * 17) {
                const n = try raw.read(&buffer);
                bufferlen = 0;
                const read = buffer[0..n];
                if (std.mem.startsWith(u8, read, "\r")) {
                    running = false;
                }
                if (std.mem.startsWith(u8, read, "\x03")) { // <C-c>
                    running = false;
                }
                if (std.mem.startsWith(u8, read, "h")) {
                    a -= 0.1;
                    b += 0.0;
                    dirty = true;
                }
                if (std.mem.startsWith(u8, read, "j")) {
                    a += 0.0;
                    b += 0.1;
                    dirty = true;
                }
                if (std.mem.startsWith(u8, read, "k")) {
                    a -= 0.0;
                    b -= 0.1;
                    dirty = true;
                }
                if (std.mem.startsWith(u8, read, "l")) {
                    a += 0.1;
                    b -= 0.0;
                    dirty = true;
                }
                // pause
                if (std.mem.eql(u8, read, "p")) {
                    paused = !paused;
                }
            }
            if (paused) {
                std.Thread.sleep(32 * std.time.ns_per_ms);
            } else {
                dirty = true;
                a += 0.05;
                b += 0.02;
            }
            if (dirty) {
                var timer_frame = try std.time.Timer.start();
                try draw.torus(&plot, raw, a, b);
                try draw.line(&plot, .{ .x = 0, .y = @floatFromInt(raw.height - 5) }, .{ .x = 36, .y = @floatFromInt(raw.height - 5) });
                try raw.goto(0, raw.height - 4);
                const elapsed: u64 = timer_frame.read();
                frame_times[frame] = elapsed;
                frame = (frame + 1) % 32;

                var sum: f32 = 0;
                for (frame_times) |t| {
                    sum += (@as(f32, @floatFromInt(t)) / 32);
                }
                try raw.print("avg     {d:<4.2}ms", .{sum / std.time.ns_per_ms});
                dirty = false;
                while (timer_frame.read() < std.time.ns_per_ms * 17) {}
            }
        }
    }
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
pub const Panic = @import("panic.zig");
