const std = @import("std");
const mathz = @import("mathz");

pub fn main() void {
    const context = .{
        .constants = .{
            .{ "ding", 360 },
            .{ "a", 3 },
        },

        .functions = .{
            .{ "sin", sin },
        },

        .ops = .{ .{
            .{ "^", pow },
        }, .{
            .{ "-", neg },
        }, .{
            .{ "*", mul },
            .{ "/", div },
        }, .{
            .{ "+", add },
            .{ "-", sub },
        } },
    };

    const x = mathz.calc(
        f128,
        exprs[0],
        context,
    );
    std.debug.print("{}\n", .{x});
}

const exprs = .{
    "   ding + 42.069 * (a - 7) / sin(5 + 2)",
    "1",
    "3 + 99",
    "(35/5)",
    "-5",
    "a ^ 2",
};

fn add(a: f128, b: f128) f128 {
    return a + b;
}

fn sub(a: f128, b: f128) f128 {
    return a - b;
}

fn mul(a: f128, b: f128) f128 {
    return a * b;
}

fn div(a: f128, b: f128) f128 {
    return a / b;
}

fn neg(x: f128) f128 {
    return -x;
}

fn pow(a: f64, b: f64) f128 {
    return std.math.pow(f64, a, b);
}

fn sin(x: f128) f128 {
    return std.math.sin(x);
}
