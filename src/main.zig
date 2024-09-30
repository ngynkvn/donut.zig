const std = @import("std");

const posix = std.posix;
const system = std.posix.system;

const tty = @import("tty.zig");
const draw = @import("draw.zig");
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

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    const start: f64 = @floatFromInt(std.time.nanoTimestamp());
    try draw.circle(allocator, raw, 20, 50, 30);
    try draw.circle(allocator, raw, 5, 40, 36);
    try draw.circle(allocator, raw, 3, 60, 32);
    try draw.curve(
        allocator,
        raw,
        .{ .x = 42, .y = 12 },
        .{ .x = 46, .y = 8 },
        .{ .x = 58, .y = 12 },
    );
    try draw.coords(allocator, raw);
    const end: f64 = @floatFromInt(std.time.nanoTimestamp());
    try raw.goto(0, 0);
    try raw.write("{d} ms.", .{(end - start) / std.time.ns_per_ms});

    var buffer: [128]u8 = undefined;
    var shift: f32 = 0.0;
    while (raw.read(&buffer) catch null) |n| {
        if (std.mem.eql(u8, buffer[0..n], "\r")) {
            return;
        }
        if (std.mem.eql(u8, buffer[0..n], "\x03")) { // <C-c>
            return;
        }
        _ = try raw.tty.write(buffer[0..n]);
        try draw.sin(allocator, raw, shift);
        shift += 0.2;
    }
}

// Tests
test {
    std.testing.refAllDecls(@This());
}
