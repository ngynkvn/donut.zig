const braille = @import("braille.zig");

/// Plotters are interfaces for drawing primitives
pub const Plotter = union(enum) {
    braille: *braille.Plotter,
    pub fn plot(self: Plotter, x: f32, y: f32) !void {
        return switch (self) {
            inline else => |plt| return plt.plot(x, y),
        };
    }
    pub fn deinit(self: Plotter) void {
        return switch (self) {
            inline else => |impl| impl.deinit(),
        };
    }
    pub fn clear(self: Plotter) void {
        return switch (self) {
            inline else => |impl| impl.clear(),
        };
    }
};
