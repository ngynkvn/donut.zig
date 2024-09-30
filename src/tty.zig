const std = @import("std");

const posix = std.posix;
const system = posix.system;

pub const TTY_HANDLE = "/dev/tty";

/// VT100 escape sequences
/// https://vt100.net/docs/vt100-ug/chapter3.html
/// `man terminfo`, `man tput`, `man infocmp`
pub const E = struct {
    /// escape code prefix
    pub const ESC = "\x1b[";
    /// goto .{x, y}
    pub const GOTO = ESC ++ "{d};{d}H";
    pub const CLEAR_DOWN = ESC ++ "0J";
    pub const CLEAR_UP = ESC ++ "1J";
    pub const CLEAR_SCREEN = ESC ++ "2J"; // NOTE: https://vt100.net/docs/vt100-ug/chapter3.html#ED
    pub const ENTER_ALT_SCREEN = ESC ++ "?1049h";
    pub const EXIT_ALT_SCREEN = ESC ++ "?1049l";
};

pub const RawMode = struct {
    orig_termios: posix.termios,
    tty: std.fs.File,
    width: u16,
    height: u16,

    /// Enter "raw mode", returning a struct that wraps around the provided tty file
    /// Entering raw mode will automatically send the sequence for entering an
    /// alternate screen (smcup)
    /// Use `defer RawMode.restore()` to reset on exit.
    /// Deferral will set the sequence for exiting alt screen (rmcup)
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
        _ = try tty.write(E.ENTER_ALT_SCREEN);
        return .{
            .orig_termios = orig_termios,
            .tty = tty,
            .width = width,
            .height = height,
        };
    }
    pub fn restore(self: RawMode) !posix.E {
        _ = try self.tty.write(E.EXIT_ALT_SCREEN);
        const rc = system.tcsetattr(self.tty.handle, .FLUSH, &self.orig_termios);
        return posix.errno(rc);
    }
    /// Move cursor to (x, y) (column, row)
    /// (0, 0) is defined as the bottom left corner of the terminal.
    pub fn goto(self: RawMode, x: usize, y: usize) !void {
        try std.fmt.format(self.tty.writer(), E.GOTO, .{ self.height - y, x });
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
///The Braille unicode range is #x2800 - #x28FF, where each dot is one of 8 bits
///    Because Braille was originally only 6 dots, the order of bits is:
///    1 4
///    2 5
///    3 6
///    7 8
pub const BRAILLE_TABLE: [256][3]u8 = ret: {
    const BRAILLE_START_CODEPOINT = 0x2800;
    var gen: [256][3]u8 = undefined;
    for (0..0x100) |value| {
        // TODO: Checkout why this is needed
        @setEvalBranchQuota(256 * 10);
        const bytes = std.unicode.utf8EncodeComptime(BRAILLE_START_CODEPOINT + value);
        gen[value] = bytes;
    }
    break :ret gen;
};
/// Braille accessor
///    1 4 -> a b
///    2 5 -> c d
///    3 6 -> e f
///    7 8 -> g h
// zig fmt: off

const B = packed struct(u8) {
    a: bool = false, c: bool = false,
    e: bool = false, b: bool = false,
    d: bool = false, f: bool = false,
    g: bool = false, h: bool = false,
};
// zig fmt: on
pub fn BraillePoint(point: u8) [3]u8 {
    return BRAILLE_TABLE[point];
}

test "braille accessor" {
    {
        const p = BraillePoint(0xff);
        try std.testing.expectEqual(BRAILLE_TABLE[255], p);
    }
    {
        const p = BraillePoint(@bitCast(B{ .a = true, .b = true }));
        try std.testing.expectEqual(BRAILLE_TABLE[0b1001], p);
    }
}
