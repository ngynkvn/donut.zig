const std = @import("std");

const posix = std.posix;
const system = posix.system;

pub const TTY_HANDLE = "/dev/tty";

/// VT100 escape sequences
/// https://vt100.net/docs/vt100-ug/chapter3.html
pub const E = struct {
    /// escape code prefix
    pub const ESC = "\x1b[";
    /// goto .{x, y}
    pub const GOTO = ESC ++ "{d};{d}H";
    pub const CLEAR_SCREEN = ESC ++ "2J"; // NOTE: https://vt100.net/docs/vt100-ug/chapter3.html#ED
    pub const ALT_SCREEN = ESC ++ "";
};

pub const RawMode = struct {
    orig_termios: posix.termios,
    tty: std.fs.File,
    width: u16,
    height: u16,

    /// Enter "raw mode", returning a struct that wraps around the provided tty file
    /// Use `defer RawMode.restore()` to reset on exit.
    pub fn enable(tty: std.fs.File) !RawMode {
        const orig_termios = try posix.tcgetattr(tty.handle);
        var raw = orig_termios;
        // explanation here: https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
        // TODO: check out the other flags later
        raw.lflag.ECHO = false; // Disable echo input
        raw.lflag.ICANON = false; // Read byte by byte
        raw.lflag.IEXTEN = false; // Disable <C-v>
        raw.iflag.ICRNL = false; // Disable <C-m>
        raw.iflag.IXON = false; // Disable <C-s> and <C-q>
        raw.oflag.OPOST = false; // Disable translating "\n" to "\r\n"

        raw.cc[@intFromEnum(system.V.MIN)] = 0; // min bytes required for read
        raw.cc[@intFromEnum(system.V.TIME)] = 2; // min time to wait for response, 100ms per unit

        // IOCGWINSZ (io control get window size (?))
        // is a request signal for window size
        var ws: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
        // Get the window size via ioctl(2) call to tty
        const result = system.ioctl(tty.handle, posix.T.IOCGWINSZ, &ws);
        if (posix.errno(result) != .SUCCESS) return error.IoctlReturnedNonZero;

        const width = ws.col;
        const height = ws.row;
        std.log.debug("ws is {}x{}\n", .{ width, height });
        return .{
            .orig_termios = orig_termios,
            .tty = tty,
            .width = width,
            .height = height,
        };
    }
    pub fn restore(self: RawMode) posix.E {
        const rc = system.tcsetattr(self.tty.handle, .FLUSH, &self.orig_termios);
        return posix.errno(rc);
    }
    /// Move cursor to (x, y)
    pub fn goto(self: RawMode, x: usize, y: usize) !void {
        try std.fmt.format(self.tty.writer(), E.GOTO, .{ x, y });
    }
    /// Move to bottom of screen
    pub fn bottom(self: RawMode) !void {
        try self.goto(self.width, self.height);
    }
    /// read input
    pub fn read(self: RawMode, buffer: []u8) !usize {
        return self.tty.read(buffer);
    }
    /// write to screen via fmt string
    pub fn write(self: RawMode, comptime fmt: []const u8, args: anytype) !void {
        try std.fmt.format(self.tty.writer(), fmt, args);
    }
};
