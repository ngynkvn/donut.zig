const std = @import("std");
const posix = std.posix;
const system = std.posix.system;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const luminence = ".,-~:;=!*#$@";

// We will draw a donut!
// Adapted from https://www.a1k0n.net/2011/07/20/donut-math.html
pub fn main() !void {
    // Get the window size via ioctl(2) call to tty
    const tty = std.io.getStdIn();
    defer tty.close();

    const raw = try enableRawMode(tty);
    defer {
        const errno = raw.restore_term();
        if (errno != .SUCCESS) {
            @panic("no good");
        }
    }

    // https://zig.news/lhp/want-to-create-a-tui-application-the-basics-of-uncooked-terminal-io-17gm
    { // INFO:
        //
        // To render a 3d object onto a 2d screen,
        // you project the (x, y, z) in 3d space so
        // that the corresponding 2D position is (x', y')
        //
        // screen position (x', y') is proportional to
        // the 3d position, the projection works out to
        // y'/z' = y/z
        // y' = (yz')/z
        // Setting z to some fixed constant k since donut will not move
    }
    const k = 5.0;
    _ = k; // autofix

    { // INFO:
        //
        // How do we draw a torus?
        // A torus is just a circle that is
        // swept around an axis to form a solid object.
        // so you need:
        //  - R1:  Circle Radius
        //  - R2:  Inner Radius (Point to sweep around)
        //  - t:   theta, 0-2pi for rotating around axis
        //  - p:   phi, 0-2pi for rotating
        //  2-D circle drawn in 3d space:
        //  - (x,y,z) = (R2, 0, 0) + (R1cos(t), R1sin(t), 0)
        //  - [sweeping a line around z]
        //  Rotate circle in y-axis:
        //
        //                                [  cos(p)  0  sin(p) ]
        // (R2 + R1cos(t), R1sin(t), 0) * [    0     1     0   ]
        //                                [ -sin(p)  0  cos(p) ]
    }

    //  2-D circle drawn in 3d space:
    //  - (x,y,z) = (R2, 0, 0) + (R1cos(t), R1sin(t), 0)
    // const r1 = 1.0;
    // const r2 = 2.0;
    // const z = 5.0;
    // const t = 2 * std.math.pi;
    //
    // const tstep = 0.1;
    // const tn = @round(t / tstep);
    //
    // for (0..tn) |i| {
    //     std.debug.print("{}", .{i});
    // }
    for (1..raw.height) |y| {
        try std.fmt.format(tty.writer(), ESC ++ "{d};{d}" ++ HOME, .{ y, y });
        try std.fmt.format(tty.writer(), "{d}", .{y});
    }
    _ = try tty.write(HOME);
}

const RawTerminal = struct {
    orig_termios: posix.termios,
    tty: std.fs.File,
    width: u16,
    height: u16,
    fn restore_term(self: RawTerminal) posix.E {
        const rc = system.tcsetattr(self.tty.handle, .FLUSH, &self.orig_termios);
        return posix.errno(rc);
    }
};
fn enableRawMode(tty: std.fs.File) !RawTerminal {
    const orig_termios = try posix.tcgetattr(tty.handle);
    var raw = orig_termios;
    // explanation here: https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
    // TODO: check out the other flags later
    raw.lflag.ECHO = false; // No echo from input
    raw.lflag.ICANON = false; // Read byte by byte

    // IOCGWINSZ (io control get window size (?))
    // is a request signal for window size
    var ws: posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
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

// Terminal Codes
const ESC = "\x1b[";
const HOME = "H";
const CURSOR_SAVE = "s";
const CURSOR_RESET = "u";
const UP = "#A";
const DOWN = "#B";
