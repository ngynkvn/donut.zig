//! This namespace is the default one used by the Zig compiler to emit various
//! kinds of safety panics, due to the logic in `std.builtin.Panic`.
//!
//! Since Zig does not have interfaces, this file serves as an example template
//! for users to provide their own alternative panic handling.
//!
//! As an alternative, see `std.debug.SimplePanic`.

const std = @import("std");
const tty = @import("tty.zig");

pub var rawterm: ?tty.RawMode = null;

/// Dumps a stack trace to standard error, then aborts.
///
/// Explicit calls to `@panic` lower to calling this function.
pub const call: fn ([]const u8, ?*std.builtin.StackTrace, ?usize) noreturn = callFn;

fn callFn(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, first_trace_addr: ?usize) noreturn {
    @branchHint(.cold);
    if (rawterm) |term| {
        @branchHint(.likely);
        //        _ = term.write(tty.E.CLEAR_SCREEN ++ tty.E.HOME, .{}) catch void;
        _ = term.restore() catch void;
    }
    std.debug.defaultPanic(msg, error_return_trace, first_trace_addr);
}

pub fn sentinelMismatch(expected: anytype, found: @TypeOf(expected)) noreturn {
    @branchHint(.cold);
    std.debug.panicExtra(null, @returnAddress(), "sentinel mismatch: expected {any}, found {any}", .{
        expected, found,
    });
}

pub fn unwrapError(ert: ?*std.builtin.StackTrace, err: anyerror) noreturn {
    @branchHint(.cold);
    std.debug.panicExtra(ert, @returnAddress(), "attempt to unwrap error: {s}", .{@errorName(err)});
}

pub fn outOfBounds(index: usize, len: usize) noreturn {
    @branchHint(.cold);
    std.debug.panicExtra(null, @returnAddress(), "index out of bounds: index {d}, len {d}", .{ index, len });
}

pub fn startGreaterThanEnd(start: usize, end: usize) noreturn {
    @branchHint(.cold);
    std.debug.panicExtra(null, @returnAddress(), "start index {d} is larger than end index {d}", .{ start, end });
}

pub fn inactiveUnionField(active: anytype, accessed: @TypeOf(active)) noreturn {
    @branchHint(.cold);
    std.debug.panicExtra(null, @returnAddress(), "access of union field '{s}' while field '{s}' is active", .{
        @tagName(accessed), @tagName(active),
    });
}

pub const messages = std.debug.SimplePanic.messages;
