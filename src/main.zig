const std = @import("std");
const ctme = @import("ctme");
const zlm = @import("zlm");

// Limitations:
// Operators within a context must be unique
// Only working on floating point numbers
// Custom functions need to be created
// Lacks validation and error checking
// No custom associativity (left-associative by default)
pub fn main() void {
    const x = ctme.calc(
        f128,
        exprs[7],
        basic,
    );
    std.debug.print("{}\n", .{x});

    const y = ctme.calc(
        f32,
        "(v1 * 2) [.] v2",
        linalg,
    );
    std.debug.print("{}\n", .{y});
}

const exprs = .{
    "   ding + 42.069 * (a - 7) / sin(5 + 2)",
    "1",
    "3 + 99",
    "(35/5)",
    "~5",
    "~a^2",
    "4 ^ (3 ^ 2)",
    "7 - 4 + 2",
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

const basic = .{
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
        .{ "~", neg },
    }, .{
        .{ "*", mul },
        .{ "/", div },
    }, .{
        .{ "+", add },
        .{ "-", sub },
    } },
};

const linalg = .{
    .constants = .{
        .{ "v1", zlm.vec2(1, 2) },
        .{ "v2", zlm.vec2(2, 1) },
    },

    .functions = .{},

    .ops = .{
        .{
            .{ "*", zlm.Vec2.scale },
            .{ "[.]", zlm.Vec2.dot },
        },
    },
};
