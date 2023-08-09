const std = @import("std");

pub fn main() void {
    const context = .{
        .constants = .{
            .{ "ding", 360 },
            .{ "a", 3 },
        },

        .functions = .{
            .{ "sin", std.math.sin },
        },

        .prec3 = .{
            .{ "+", std.math.add },
            .{ "-", std.math.sub },
        },

        .prec2 = .{
            .{ "*", std.math.mul },
            .{ "/", std.math.divExact },
        },

        .prec1 = .{},

        .prec0 = .{},
    };

    calc(context, "   ding + 42.069 * (a - 7) / sin(5 + 2)");
}

pub fn calc(comptime context: anytype, comptime expression: []const u8) void {
    comptime var t = Tokenizer{ .expr = expression };
    const tokens: []const Token = comptime t.tokenize();
    print_tokens(tokens);

    comptime var p = Parser{ .tokens = tokens };
    comptime var tree: Node = p.parse_prec3(context);
    print_tree(tree, 0);
}

const Token = struct {
    tag: Tag,
    str: []const u8,

    const Tag = enum { int, float, ident, func, op };

    fn init(tag: Tag, str: []const u8) Token {
        return Token{ .tag = tag, .str = str };
    }
};

const Tokenizer = struct {
    expr: []const u8,
    idx: usize = 0,

    fn tokenize(comptime t: *Tokenizer) []const Token {
        var tokens: []const Token = &.{};

        inline while (t.idx < t.expr.len) {
            const c = t.expr[t.idx];

            if (std.ascii.isWhitespace(c)) {
                t.idx += 1;
                continue;
            }

            tokens = tokens ++ switch (c) {
                '0'...'9' => blk: {
                    const integral = slice_using(t, std.ascii.isDigit);
                    if (t.idx < t.expr.len and t.expr[t.idx] != '.') {
                        break :blk .{Token.init(.int, integral)};
                    } else {
                        t.idx += 1;
                        const fractional = slice_using(t, std.ascii.isDigit);
                        const decimal = integral ++ "." ++ fractional;
                        break :blk .{Token.init(.float, decimal)};
                    }
                },
                '_', 'a'...'z', 'A'...'Z' => blk: {
                    const ident = slice_using(t, is_part_identifier);
                    if (t.idx < t.expr.len and t.expr[t.idx] == '(') {
                        break :blk .{Token.init(.func, ident)};
                    } else {
                        break :blk .{Token.init(.ident, ident)};
                    }
                },
                '(', ')', ',' => blk: {
                    defer t.idx += 1;
                    break :blk .{Token.init(.op, &[_]u8{t.expr[t.idx]})};
                },
                else => blk: {
                    if (std.ascii.isPrint(c)) {
                        const op = slice_using(t, is_part_operator);
                        break :blk .{Token.init(.op, op)};
                    } else {
                        @compileError("Invalid char in expr: " ++ &[_]u8{c});
                    }
                },
            };
        }
        return tokens;
    }

    fn slice_using(t: *Tokenizer, comptime pred: fn (c: u8) bool) []const u8 {
        var start: usize = t.idx;
        while (t.idx < t.expr.len and pred(t.expr[t.idx])) t.idx += 1;
        return t.expr[start..t.idx];
    }

    fn is_part_identifier(c: u8) bool {
        return c == '_' or std.ascii.isAlphabetic(c) or std.ascii.isDigit(c);
    }

    fn is_part_operator(c: u8) bool {
        for ("!#$%&'*+-./:;<=>?@[\\]^`|~") |s| if (c == s) return true;
        return false;
    }
};

const Node = struct {
    token: *const Token,
    data: []const Node,

    fn init(token: *const Token, data: []const Node) Node {
        return Node{ .token = token, .data = data };
    }
};

const Parser = struct {
    tokens: []const Token,
    idx: usize = 0,

    fn parse_prec3(p: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec2(p, context);
        comptime var tkn: *const Token = &p.tokens[p.idx];

        while (tkn.tag == .op and has_key(context.prec3, tkn.str)) {
            p.idx += 1;
            node = Node.init(tkn, &[_]Node{ node, parse_prec2(p, context) });
            tkn = &p.tokens[p.idx];
        }
        return node;
    }

    fn parse_prec2(p: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec1(p, context);
        comptime var tkn: *const Token = &p.tokens[p.idx];

        while (tkn.tag == .op and has_key(context.prec2, tkn.str)) {
            p.idx += 1;
            node = Node.init(tkn, &[_]Node{ node, parse_prec1(p, context) });
            tkn = &p.tokens[p.idx];
        }
        return node;
    }

    fn parse_prec1(p: *Parser, context: anytype) Node {
        const tkn: *const Token = &p.tokens[p.idx];

        if (tkn.tag == .op and has_key(context.prec1, tkn.str)) {
            p.idx += 1;
            return Node.init(tkn, &[_]Node{parse_prec1(p, context)});
        }
        return parse_prec0(p, context);
    }

    fn parse_prec0(p: *Parser, context: anytype) Node {
        const tkn = &p.tokens[p.idx];

        if (is_symbol(p, '(')) {
            p.idx += 1;
            const node: Node = parse_prec3(p, context);
            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            p.idx += 1;
            return node;
        }

        if (tkn.tag == .func and has_key(context.functions, tkn.str)) {
            p.idx += 2;
            comptime var args: []const Node = &.{};

            while (p.idx < p.tokens.len and !is_symbol(p, ')')) {
                if (is_symbol(p, ',')) {
                    p.idx += 1;
                    continue;
                }
                args = args ++ .{parse_prec3(p, context)};
            }

            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            return Node.init(tkn, args);
        }

        p.idx += 1;
        return Node.init(tkn, &[_]Node{});
    }

    fn has_key(tuple: anytype, key: []const u8) bool {
        for (tuple) |t| if (comptime std.mem.eql(u8, t[0], key)) return true;
        return false;
    }

    fn is_symbol(p: *Parser, symbol: u8) bool {
        return p.tokens[p.idx].str[0] == symbol;
    }
};

fn Evaluator(comptime ctx: anytype) type {
    comptime var info: std.builtin.Type.Union = .{
        .layout = .Auto,
        .tag_type = null,
        .fields = &.{},
        .decls = &.{},
    };

    outer: inline for (ctx.one) |pair| {
        var rt = if (@typeInfo(@TypeOf(pair[1])) == .Fn)
            @typeInfo(@TypeOf(pair[1])).Fn.return_type.?
        else
            @TypeOf(pair[1]);

        for (info.fields) |f| if (f.type == rt) continue :outer;

        info.fields = info.fields ++ .{.{
            .name = @typeName(rt),
            .type = rt,
            .alignment = @alignOf(rt),
        }};
    }

    return struct {
        context: @TypeOf(ctx) = ctx,
        type: type = @Type(.{ .Union = info }),

        const Self = @This();

        fn wrap(comptime e: Self, x: anytype) e.type {
            return @unionInit(e.type, @typeName(@TypeOf(x)), x);
        }

        fn get(e: Self, array: anytype, key: []const u8) ?e.type {
            for (array) |pair| if (std.mem.eql(u8, key, pair[0]))
                return e.wrap(pair[1]);
            return null;
        }

        fn evaluate(e: Self, node: Node) e.type {
            if (node.data.len == 0 and node.token.tag != .func) {
                return switch (node.token.tag) {
                    .int => e.wrap(std.fmt.parseInt(comptime_int, node.token.str, 10) catch unreachable),
                    .float => e.wrap(std.fmt.parseFloat(comptime_float, node.token.str) catch unreachable),
                    .ident => blk: {
                        if (e.get(e.context.constants, node.token.str)) |value|
                            break :blk value;

                        //if (variables, node.token.str)) |value|
                        //    break :blk value;

                        @compileError("Missing identifier: " ++ node.token.str);
                    },
                    else => unreachable,
                };
            }

            comptime var args = &.{};
            inline for (node.data) |arg| {
                const val = switch (e.evaluate(arg)) {
                    inline else => |x| x,
                };
                args = args ++ .{val};
            }

            // I should change the type union to just get the type of the value
            // including functions, as that will be a convenient way of
            // retrieving both values and functions

            //const f = get func
            //return @call(.auto, f, args);
        }
    };
}

// Debug functions
fn print_tokens(ts: []const Token) void {
    for (ts) |t| std.debug.print("{s} [{s}]\n", .{ t.str, @tagName(t.tag) });
    std.debug.print("\n", .{});
}

fn print_tree(n: Node, i: usize) void {
    for (0..i) |_| std.debug.print("   ", .{});
    std.debug.print("{s} [{s}]\n", .{ n.token.str, @tagName(n.token.tag) });
    for (n.data) |d| print_tree(d, i + 1);
}
