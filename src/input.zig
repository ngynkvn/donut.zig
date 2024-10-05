const std = @import("std");
const tty = @import("tty.zig");

const InputHandler = struct { thread: std.Thread };
pub fn start_handler(raw: tty.RawMode) !InputHandler {
    const thread = try std.Thread.spawn(.{}, input_handler, .{raw});
    return InputHandler{ .thread = thread };
}

var buffer: [32]u8 = .{0} ** 32;
var bufferlen: usize = 0;
fn input_handler(raw: tty.RawMode) !void {
    var timer_read = try std.time.Timer.start();
    while (true) {
        if (timer_read.read() < std.time.ns_per_ms * 100) {
            continue;
        }
        bufferlen = try raw.read(&buffer);
        _ = timer_read.lap();
    }
}
