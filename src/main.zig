const std = @import("std");

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const input = @import("input.zig");
const plotter = @import("plotter.zig");
const braille = @import("braille.zig");
const raytrace = @import("raytrace.zig");
const drawtests = @import("drawtests.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
const allocator = gpa.allocator();

/// Run a bunch of test routines, continuing to next when 'Enter' is pressed.
pub fn main() !void {
    try init_logger();
    std.log.scoped(.default).info("logging started", .{});
    defer log_file.close();
    const ttyh = try std.fs.openFileAbsolute(tty.CONFIG.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close();

    var raw = try tty.RawMode.enable(ttyh);
    defer {
        const errno = raw.restore() catch @panic("failed to write :(");
        std.debug.print("{}\n", .{gpa.deinit()});
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }

    var input_handler = input.InputHandler.init(raw, null);
    // Sphere test
    {
        var plt = raytrace.Plotter.init(allocator, raw);
        defer plt.deinit();
        try raytrace.sphere(&plt, raw);
        const top_left = draw.Point{ .x = 1, .y = 1 };
        const bot_right = draw.Point{ .x = 20, .y = 10 };
        try draw.box(raw, top_left, bot_right, false);
        switch (input_handler.waitFor()) {
            .quit => return,
            else => {},
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
        tty.nbytes = 0;
        var a: f32 = 0.0;
        var b: f32 = -0.4;
        var paused = false;
        var dirty = true;
        try raw.print(E.SET_ANSI_FG ++ E.CLEAR_SCREEN, .{3});
        var running = true;
        while (running) {
            if (input_handler.poll()) |cmd| switch (cmd) {
                .enter => running = false,
                .quit => running = false,
                .pause => paused = !paused,
                // zig fmt: off
                .kh => { a -= 0.1; b += 0.0; dirty = true; },
                .kj => { a += 0.0; b += 0.1; dirty = true; },
                .kk => { a -= 0.0; b -= 0.1; dirty = true; },
                .kl => { a += 0.1; b -= 0.0; dirty = true; },
                // zig fmt: on
            };

            if (paused) {
                std.Thread.sleep(32 * std.time.ns_per_ms);
            } else {
                dirty = true;
                a += 0.05;
                b += 0.02;
            }
            if (!dirty) {
                continue;
            }
            var timer_frame = try std.time.Timer.start();
            try raw.gotorc(8, 0);
            try raw.print(E.CLEAR_DOWN, .{});
            try draw.torus(&plot, raw, a, b);
            try raw.gotorc(4, 0);
            try raw.print("nbytes={}", .{tty.nbytes});
            tty.nbytes = 0;
            dirty = false;
            while (timer_frame.read() < std.time.ns_per_ms * 16) std.Thread.sleep(std.time.ns_per_ms);
        }
    }
}

// Setup handlers
pub const Panic = @import("panic.zig");

var log_file: std.fs.File = undefined;
fn init_logger() !void {
    log_file = try std.fs.cwd().createFile("./donut.log", .{});
}

pub const std_options = .{
    .logFn = logFn,
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than
    // .raytrace and the default
    const scope_prefix = "(" ++ switch (scope) {
        .raytrace, std.log.default_log_scope => @tagName(scope),
        else => @tagName(scope),
        //else => return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    log_file.lock(.exclusive) catch return;
    defer log_file.unlock();
    const writer = log_file.writer();
    nosuspend writer.print(prefix ++ format ++ "\n", args) catch return;
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
