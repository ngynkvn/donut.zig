const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const Allocator = mem.Allocator;

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const input = @import("input.zig");
const plotter = @import("plotter.zig");
const braille = @import("braille.zig");
const raytrace = @import("raytrace.zig");
const drawtests = @import("drawtests.zig");
const tracy = @import("tracy.zig");
const E = tty.E;

/// Run a bunch of test routines, continuing to next when 'Enter' is pressed.
pub fn main(init: std.process.Init) !void {
    log_io = init.io;
    try init_logger();
    std.log.scoped(.default).info("logging started, tracy enabled? {}; enabled_allocation {}; enable_callstack {}", .{ tracy.enable, tracy.enable_allocation, tracy.enable_callstack });
    defer log_file.close(init.io);
    const ttyh = try Io.Dir.openFileAbsolute(init.io, tty.CONFIG.TTY_HANDLE, .{ .mode = .read_write });
    defer ttyh.close(init.io);
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.print("{}\n", .{gpa.deinit()});
    if (tracy.enable_allocation) {
        var gpa_tracy = tracy.tracyAllocator(gpa.allocator());
        return run(gpa_tracy.allocator(), init.io, ttyh);
    }
    return run(gpa.allocator(), init.io, ttyh);
}

fn run(allocator: Allocator, io: Io, ttyh: Io.File) !void {
    tracy.message("start");

    var raw_mode = try tty.RawMode.init(allocator, io, ttyh);
    const raw = &raw_mode;
    defer {
        const errno = raw.deinit() catch std.debug.panic("failed to write :(", .{});
        if (errno != .SUCCESS) std.debug.panic("errno was {}", .{errno});
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
        var frame = try @import("frame.zig").Frame.init(allocator, raw.width, raw.height);
        defer frame.deinit();
        tty.nbytes = 0;
        var a: f32 = 0.0;
        var b: f32 = -0.4;
        var paused = false;
        var dirty = true;
        try raw.print(E.SET_ANSI_FG ++ E.CLEAR_SCREEN, .{3});
        var running = true;
        while (running) {
            const tframe = tracy.traceNamed(@src(), "frame");
            defer tframe.end();
            defer tracy.frameMarkNamed("torus");
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
                try io.sleep(.fromMilliseconds(32), .awake);
            } else {
                dirty = true;
                a += 0.05;
                b += 0.02;
            }
            if (!dirty) {
                continue;
            }
            const frame_start = Io.Clock.awake.now(io);
            try draw.torus(&frame, raw, a, b);
            const elapsed = frame_start.untilNow(io, .awake).toNanoseconds();
            var status_buffer: [160]u8 = undefined;
            const status = try std.fmt.bufPrint(&status_buffer, "{d:.2} ms | {d} bytes/frame | a={d:.2} b={d:.2}", .{
                @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms,
                raw.buffer.written().len,
                a,
                b,
            });
            try raw.gotorc(1, 1);
            try raw.print(E.SET_ANSI_FG ++ E.CLEAR_LINE, .{3});
            _ = try raw.write(status[0..@min(status.len, raw.width)]);
            tty.nbytes = 0;
            tty.gotos = 0;
            dirty = false;
            try raw.flush();
            const tsleep = tracy.traceNamed(@src(), "sleeping");
            defer tsleep.end();
            const remaining = 16 * std.time.ns_per_ms - frame_start.untilNow(io, .awake).toNanoseconds();
            if (remaining > 0) try io.sleep(.fromNanoseconds(remaining), .awake);
        }
    }
}

var log_file: Io.File = undefined;
var log_io: Io = undefined;
fn init_logger() !void {
    log_file = try Io.Dir.cwd().createFile(log_io, "./donut.log", .{});
}

pub const std_options: std.Options = .{
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

    log_file.lock(log_io, .exclusive) catch return;
    defer log_file.unlock(log_io);
    var buffer: [4096]u8 = undefined;
    var writer = log_file.writerStreaming(log_io, &buffer);
    writer.interface.print(prefix ++ format ++ "\n", args) catch return;
    writer.interface.flush() catch return;
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
