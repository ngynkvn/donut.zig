const braille = @import("braille.zig");

/// Plotters are interfaces for drawing primitives
const Plotter = union(enum) {
    braille: braille.Plotter,
    fn plot(self: Plotter, x: f32, y: f32) void {
        return switch (self) {
            .braille => |plt| return plt.plot(x, y),
        };
    }
};
