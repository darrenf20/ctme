const std = @import("std");
const mathz = @import("mathz");

pub fn main() void {
    const context = .{
        .constants = .{
            .{ "ding", 360 },
            .{ "a", 3 },
        },

        .functions = .{
            .{ "sin", std.math.sin },
        },

        .ops = .{ .{
            .{ "*", std.math.mul },
            .{ "/", std.math.divExact },
        }, .{
            .{ "+", std.math.add },
            .{ "-", std.math.sub },
        } },
    };

    mathz.calc(context, "   ding + 42.069 * (a - 7) / sin(5 + 2)");
}
