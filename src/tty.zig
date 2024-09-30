const std = @import("std");

const posix = std.posix;
const system = posix.system;

pub const TTY_HANDLE = "/dev/tty";

/// vt100 / xterm escape sequences
/// References used:
///  - https://vt100.net/docs/vt100-ug/chapter3.html
///  - `man terminfo`, `man tput`, `man infocmp`
pub const E = struct {
    /// escape code prefix
    pub const ESC = "\x1b[";
    /// goto .{x, y}
    pub const GOTO = ESC ++ "{d};{d}H";
    pub const CLEAR_LINE = ESC ++ "K";
    pub const CLEAR_DOWN = ESC ++ "0J";
    pub const CLEAR_UP = ESC ++ "1J";
    pub const CLEAR_SCREEN = ESC ++ "2J"; // NOTE: https://vt100.net/docs/vt100-ug/chapter3.html#ED
    pub const ENTER_ALT_SCREEN = ESC ++ "?1049h";
    pub const EXIT_ALT_SCREEN = ESC ++ "?1049l";
    pub const REPORT_CURSOR_POS = ESC ++ "6n";
};

pub const RawMode = struct {
    orig_termios: posix.termios,
    tty: std.fs.File,
    width: u16,
    height: u16,
    const CursorPos = struct { row: usize, col: usize };

    /// Enter "raw mode", returning a struct that wraps around the provided tty file
    /// Entering raw mode will automatically send the sequence for entering an
    /// alternate screen (smcup)
    /// Use `defer RawMode.restore()` to reset on exit.
    /// Deferral will set the sequence for exiting alt screen (rmcup)
    pub fn enable(tty: std.fs.File) !RawMode {
        const orig_termios = try posix.tcgetattr(tty.handle);
        var raw = orig_termios;
        // explanation here: https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
        // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
        // TODO: check out the other flags later
        raw.lflag.ECHO = false; // Disable echo input
        raw.lflag.ICANON = false; // Read byte by byte
        raw.lflag.IEXTEN = false; // Disable <C-v>
        //raw.lflag.ISIG = false; // Disable <C-c> and <C-z>
        raw.iflag.IXON = false; // Disable <C-s> and <C-q>
        raw.iflag.ICRNL = false; // Disable <C-m>
        raw.iflag.BRKINT = false; // Break condition sends SIGINT
        raw.iflag.INPCK = false; // Enable parity checking
        raw.iflag.ISTRIP = false; // Strip 8th bit of input byte
        raw.oflag.OPOST = false; // Disable translating "\n" to "\r\n"
        raw.cflag.CSIZE = .CS8;

        raw.cc[@intFromEnum(system.V.MIN)] = 0; // min bytes required for read
        raw.cc[@intFromEnum(system.V.TIME)] = 1; // min time to wait for response, 100ms per unit
        const rc = posix.errno(system.tcsetattr(tty.handle, .FLUSH, &raw));
        if (rc != .SUCCESS) {
            return error.CouldNotSetTermiosFlags;
        }

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
        try self.write(E.GOTO, .{ self.height - y, x });
    }
    pub fn query(self: RawMode) !CursorPos {
        _ = try self.tty.write(E.REPORT_CURSOR_POS);
        // TODO: make this more durable
        var buf: [32]u8 = undefined;
        const n = try self.tty.read(&buf);
        if (!std.mem.startsWith(u8, &buf, E.ESC)) return error.UnknownResponse;
        const semi = std.mem.indexOf(u8, &buf, ";") orelse return error.ParseError;
        const row = try std.fmt.parseUnsigned(usize, buf[2..semi], 10);
        const col = try std.fmt.parseUnsigned(usize, buf[semi + 1 .. n - 1], 10);
        return .{ .row = row, .col = col };
    }
    /// read input
    pub fn read(self: RawMode, buffer: []u8) !usize {
        return self.tty.read(buffer);
    }
    /// write to screen via fmt string
    pub fn write(self: RawMode, comptime fmt: []const u8, args: anytype) !void {
        try self.tty.writer().print(fmt, args);
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

///Set a u8 representing a braille code as a bitmap
///    0 3 -> 03 13 | 000 011
///    1 4 -> 02 12 | 001 100
///    2 5 -> 01 11 | 010 101
///    6 7 -> 00 10 | 110 111
pub fn set_bbit(braille_bit: u8, x: u1, y: u2) u8 {
    // TODO: check for better way to do this
    var pos: u3 = ((3 - y) + @as(u3, x) * 3);
    if (y == 0) pos = 6 + @as(u3, x);
    return braille_bit | (@as(u8, 1) << @truncate(pos));
}

pub fn BraillePoint(point: u8) [3]u8 {
    return BRAILLE_TABLE[point];
}

test "braille accessor" {
    {
        const p = BraillePoint(0xff);
        try std.testing.expectEqual(BRAILLE_TABLE[255], p);
    }
    {
        try std.testing.expectEqual(
            0b0100_0000,
            set_bbit(0, 0, 0),
        );
        try std.testing.expectEqual(
            0b1000_0000,
            set_bbit(0, 1, 0),
        );
        try std.testing.expectEqual(
            0b0000_1000,
            set_bbit(0, 1, 3),
        );
    }
}
