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
            .{ "*", mul },
            .{ "/", div },
        }, .{
            .{ "+", add },
            .{ "-", sub },
        } },
    };

    const x = mathz.calc(comptime_float, "   ding + 42.069 * (a - 7) / sin(5 + 2)", context);
    std.debug.print("{}\n", .{x});
}

fn add(comptime a: anytype, comptime b: anytype) comptime_float {
    return a + b;
}

fn sub(comptime a: anytype, comptime b: anytype) comptime_float {
    return a - b;
}

fn mul(comptime a: anytype, comptime b: anytype) comptime_float {
    return a * b;
}

fn div(comptime a: anytype, comptime b: anytype) comptime_float {
    return a / b;
}
