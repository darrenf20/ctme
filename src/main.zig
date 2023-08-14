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
        f128,
        "   ding + 42.069 * (a - 7) / sin(5 + 2)",
        context,
    );
    _ = x;
    //std.debug.print("{}\n", .{x});
}

fn add(comptime a: f128, comptime b: f128) f128 {
    return a + b;
}

fn sub(comptime a: f128, comptime b: f128) f128 {
    return a - b;
}

fn mul(comptime a: f128, comptime b: f128) f128 {
    return a * b;
}

fn div(comptime a: f128, comptime b: f128) f128 {
    return a / b;
}
