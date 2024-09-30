const std = @import("std");

const posix = std.posix;
const system = posix.system;

pub const TTY_HANDLE = "/dev/tty";

/// vt100 / xterm escape sequences
/// References used:
///  - https://vt100.net/docs/vt100-ug/chapter3.html
///  - `man terminfo`, `man tput`, `man infocmp`
// zig fmt: off
pub const E = struct {
    /// escape code prefix
    pub const ESC = "\x1b[";
    /// goto .{x, y}
    pub const GOTO              = ESC ++ "{d};{d}H";
    pub const CLEAR_LINE        = ESC ++ "K";
    pub const CLEAR_DOWN        = ESC ++ "0J";
    pub const CLEAR_UP          = ESC ++ "1J";
    pub const CLEAR_SCREEN      = ESC ++ "2J"; // NOTE: https://vt100.net/docs/vt100-ug/chapter3.html#ED
    pub const ENTER_ALT_SCREEN  = ESC ++ "?1049h";
    pub const EXIT_ALT_SCREEN   = ESC ++ "?1049l";
    pub const REPORT_CURSOR_POS = ESC ++ "6n";
    pub const CURSOR_INVISIBLE  = ESC ++ "?25l";
    pub const CURSOR_VISIBLE    = ESC ++ "?12;25h";
    /// setaf .{color}
    pub const SET_ANSI_FG       = ESC ++ "3{d}m";
    pub const RESET_COLORS      = ESC ++ "m";
};
// zig fmt: on

pub const RawMode = struct {
    orig_termios: posix.termios,
    tty: std.fs.File,
    width: u16,
    height: u16,
    const CursorPos = struct { row: usize, col: usize };

    /// Enter "raw mode", returning a struct that wraps around the provided tty file
    /// Entering raw mode will automatically send the sequence for entering an
    /// alternate screen (smcup) and hiding the cursor.
    /// Use `defer RawMode.restore()` to reset on exit.
    /// Deferral will set the sequence for exiting alt screen (rmcup)
    ///
    /// Explanation here: https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
    /// https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    pub fn enable(tty: std.fs.File) !RawMode {
        const orig_termios = try posix.tcgetattr(tty.handle);
        var raw = orig_termios;
        // Some explanation of the flags can be found in the links above.
        // TODO: check out the other flags later
        raw.lflag.ECHO = false; // Disable echo input
        raw.lflag.ICANON = false; // Read byte by byte
        raw.lflag.IEXTEN = false; // Disable <C-v>
        raw.lflag.ISIG = false; // Disable <C-c> and <C-z>
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
        _ = try tty.write(E.ENTER_ALT_SCREEN ++ E.CURSOR_INVISIBLE);
        return .{
            .orig_termios = orig_termios,
            .tty = tty,
            .width = width,
            .height = height,
        };
    }
    pub fn restore(self: RawMode) !posix.E {
        _ = try self.tty.write(E.EXIT_ALT_SCREEN ++ E.CURSOR_VISIBLE);
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
