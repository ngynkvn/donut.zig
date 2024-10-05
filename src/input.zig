const std = @import("std");
const tty = @import("tty.zig");

pub const Command = enum { quit, enter, kh, kj, kk, kl, pause };
pub const Keymap = struct { key: []const u8, command: Command };
pub const default_keys = [_]Keymap{
    .{ .key = "\r", .command = .enter },
    .{ .key = "h", .command = .kh },
    .{ .key = "j", .command = .kj },
    .{ .key = "k", .command = .kk },
    .{ .key = "l", .command = .kl },
    .{ .key = "p", .command = .pause },
    // <C-c>
    .{ .key = "\x03", .command = .quit },
};

pub const InputHandler = struct {
    raw: tty.RawMode,
    keymaps: []const Keymap,
    poll_interval_ms: usize = 32,
    poll_timeout_ms: usize = 32,
    const npm = std.time.ns_per_ms;
    pub fn init(raw: tty.RawMode, keymaps: ?[]Keymap) InputHandler {
        return InputHandler{
            .raw = raw,
            .keymaps = keymaps orelse &default_keys,
        };
    }
    pub fn poll(self: InputHandler) ?Command {
        var timeout = std.time.Timer.start() catch @panic("Your system does not support timers!");
        var buffer: [16]u8 = undefined;
        while (timeout.read() < self.poll_timeout_ms * npm) {
            const n = self.raw.read(&buffer) catch @panic("Unable to read from tty");
            const read = buffer[0..n];
            for (self.keymaps) |keymap| {
                if (std.mem.startsWith(u8, read, keymap.key)) return keymap.command;
            }
        }
        return null;
    }

    pub fn waitFor(self: InputHandler) Command {
        var timer_read = std.time.Timer.start() catch @panic("Your system does not support timers!");
        var buffer: [16]u8 = undefined;
        while (true) {
            if (timer_read.read() < self.poll_interval_ms * npm) continue;
            timer_read.reset();
            const n = self.raw.read(&buffer) catch @panic("Unable to read from tty");
            const read = buffer[0..n];
            for (self.keymaps) |keymap| {
                if (std.mem.startsWith(u8, read, keymap.key)) return keymap.command;
            }
        }
    }
};
