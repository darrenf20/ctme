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

        .ops = .{ .{
            .{ "*", std.math.mul },
            .{ "/", std.math.divExact },
        }, .{
            .{ "+", std.math.add },
            .{ "-", std.math.sub },
        } },
    };

    calc(context, "   ding + 42.069 * (a - 7) / sin(5 + 2)");
}

pub fn calc(comptime ctx: anytype, comptime expression: []const u8) void {
    comptime var t = Tokenizer{ .expr = expression };
    const tokens: []const Token = comptime t.tokenize();
    print_tokens(tokens);

    comptime var p = Parser{ .tokens = tokens };
    comptime var tree: Node = p.parse_prec3(ctx.ops.len - 1, ctx);
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

    fn parse_prec(p: *Parser, comptime n: usize, ctx: anytype) Node {
        comptime var tkn = &p.tokens[p.idx];
        const num = has_key(ctx.ops[n], tkn.str);
        comptime var node: Node = if (num) |_| p.parse_prec(n - 1, ctx) else undefined;

        while (tkn.tag == .op and has_key(ctx.ops[n], tkn.str) != null) {
            p.idx += 1;
            if (num == 1) return Node.init(tkn, &[_]Node{p.parse_prec(n, ctx)});
            node = Node.init(tkn, &[_]Node{ node, p.parse_prec(n - 1, ctx) });
            tkn = &p.tokens[p.idx];
        }

        if (num == 1) return p.parse_final(ctx);
        return node;
    }

    fn parse_final(p: *Parser, ctx: anytype) Node {
        const tkn = &p.tokens[p.idx];

        if (is_symbol(p, '(')) {
            p.idx += 1;
            const node = p.parse_prec(ctx.ops.len - 1, ctx);
            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            p.idx += 1;
            return node;
        }

        if (tkn.tag == .func and has_key(ctx.functions, tkn.str) != null) {
            p.idx += 2;
            comptime var args: []const Node = &.{};

            while (p.idx < p.tokens.len and !is_symbol(p, ')')) {
                if (is_symbol(p, ',')) {
                    p.idx += 1;
                    continue;
                }
                args = args ++ .{p.parse_prec(ctx.ops.len - 1, ctx)};
            }

            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            return Node.init(tkn, args);
        }

        p.idx += 1;
        return Node.init(tkn, &[_]Node{});
    }

    fn has_key(tuple: anytype, key: []const u8) ?u2 {
        for (tuple) |t| if (comptime std.mem.eql(u8, t[0], key)) {
            return @typeInfo(@TypeOf(t[1])).Fn.params.len;
        };
        return null;
    }

    fn is_symbol(p: *Parser, symbol: u8) bool {
        return p.tokens[p.idx].str[0] == symbol;
    }
};

fn evaluate(comptime T: anytype, node: Node, ctx: anytype) T {
    if (node.data.len == 0 and node.token.tag != .func) {
        switch (node.token.tag) {
            .int => return std.fmt.parseInt(T, node.token.str, 10) catch unreachable,
            .float => return std.fmt.parseFloat(T, node.token.str) catch unreachable,
            .ident => {
                //if (find(ctx.constants, node.token.str)) |i| {
                //    return ctx.constants[i][1];
                //}
            },
            else => unreachable,
        }
    }

    comptime var args = &.{};
    inline for (node.data) |arg| {
        args = args ++ .{evaluate(arg.rtype, arg, ctx)};
    }
    //const f = get func
    //return @call(.auto, f, args);
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
