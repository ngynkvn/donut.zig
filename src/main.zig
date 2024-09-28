const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const luminence = ".,-~:;=!*#$@";

pub fn main() !void {
    // Get the window size via ioctl(2) call to tty
    const tty = try std.fs.openFileAbsolute("/dev/tty", .{});
    defer tty.close();
    var ws: std.posix.winsize = .{
        .row = 0,
        .col = 0,
        .xpixel = 0,
        .ypixel = 0,
    };
    // IOCGWINSZ (io control get window size (?)) is a request signal for window size
    const result = std.posix.system.ioctl(tty.handle, std.posix.T.IOCGWINSZ, &ws);
    if (result != 0) {
        return error.IoctlReturnedNonZero;
    }

    const width = ws.col;
    const height = ws.row;
    std.log.debug("ws is {}x{}\n", .{ width, height });
}
