const std = @import("std");

const posix = std.posix;
const system = std.posix.system;

const tty = @import("tty.zig");
const draw = @import("draw.zig");
const E = tty.E;
var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
const allocator = gpa.allocator();

/// We will draw a donut!
/// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
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

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    try draw.circle(raw);
    try draw.coords(raw);

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

// Tests
test {
    std.testing.refAllDecls(@This());
}
