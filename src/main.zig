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

    const x = mathz.calc(
        comptime_float,
        "   ding + 42.069 * (a - 7) / sin(5 + 2)",
        context,
    );
    _ = x;
    //std.debug.print("{}\n", .{x});
}

fn add(comptime a: comptime_float, comptime b: comptime_float) comptime_float {
    return a + b;
}

fn sub(comptime a: comptime_float, comptime b: comptime_float) comptime_float {
    return a - b;
}

fn mul(comptime a: comptime_float, comptime b: comptime_float) comptime_float {
    return a * b;
}

fn div(comptime a: comptime_float, comptime b: comptime_float) comptime_float {
    return a / b;
}
