const std = @import("std");

pub fn calc(
    comptime T: anytype,
    comptime expression: []const u8,
    comptime ctx: anytype,
) T {
    comptime var t = Tokenizer{ .expr = expression };
    const tokens = comptime t.tokenize();
    comptime var p = Parser{ .tokens = tokens };
    const tree = comptime p.parse_op(ctx.ops.len, ctx);
    return evaluate(T, tree, ctx);
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
                    if (t.idx == t.expr.len or t.expr[t.idx] != '.') {
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
                    if (t.idx == t.expr.len or t.expr[t.idx] == '(') {
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
                    }
                    @compileError("Invalid char in expr: " ++ &[_]u8{c});
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

    fn parse_op(comptime p: *Parser, comptime n: usize, ctx: anytype) Node {
        if (n == 0) return p.parse_final(ctx);

        const unary = ctx.ops[n - 1].len > 0 and
            @typeInfo(@TypeOf(ctx.ops[n - 1][0][1])).Fn.params.len == 1;

        comptime var node: Node = if (unary) undefined else p.parse_op(n - 1, ctx);
        if (p.idx == p.tokens.len) return node;
        comptime var tkn = &p.tokens[p.idx];

        while (tkn.tag == .op and has_key(ctx.ops[n - 1], tkn.str)) {
            p.idx += 1;
            if (unary) return Node.init(tkn, &[_]Node{p.parse_op(n, ctx)});
            node = Node.init(tkn, &[_]Node{ node, p.parse_op(n - 1, ctx) });
            if (p.idx < p.tokens.len) tkn = &p.tokens[p.idx] else break;
        }

        if (unary) return p.parse_op(n - 1, ctx);
        return node;
    }

    fn parse_final(comptime p: *Parser, ctx: anytype) Node {
        const tkn = &p.tokens[p.idx];

        if (is_symbol(p, '(')) {
            p.idx += 1;
            const node = p.parse_op(ctx.ops.len, ctx);
            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            p.idx += 1;
            return node;
        }

        if (tkn.tag == .func and has_key(ctx.functions, tkn.str)) {
            p.idx += 2;
            comptime var args: []const Node = &.{};

            while (p.idx < p.tokens.len and !is_symbol(p, ')')) {
                if (is_symbol(p, ',')) {
                    p.idx += 1;
                    continue;
                }
                args = args ++ .{p.parse_op(ctx.ops.len, ctx)};
            }

            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            return Node.init(tkn, args);
        }

        p.idx += 1;
        return Node.init(tkn, &[_]Node{});
    }

    fn has_key(tuple: anytype, comptime key: []const u8) bool {
        inline for (tuple) |t| if (comptime std.mem.eql(u8, t[0], key)) return true;
        return false;
    }

    fn is_symbol(p: *Parser, symbol: u8) bool {
        return p.tokens[p.idx].str[0] == symbol;
    }
};

fn get(comptime T: type, comptime array: anytype, comptime key: []const u8) ?T {
    for (array) |pair| if (std.mem.eql(u8, key, pair[0])) return pair[1];
    return null;
}

fn evaluate(comptime T: type, comptime node: Node, comptime ctx: anytype) T {
    if (node.data.len == 0 and node.token.tag != .func) {
        return switch (node.token.tag) {
            //.int => std.fmt.parseInt(T, node.token.str, 10) catch unreachable,
            .int, .float => std.fmt.parseFloat(T, node.token.str) catch unreachable,
            .ident => blk: {
                if (get(T, ctx.constants, node.token.str)) |value|
                    break :blk value;

                //if (variables, node.token.str)) |value|
                //    break :blk value;

                @compileError("Missing identifier: " ++ node.token.str);
            },
            else => unreachable,
        };
    }

    const func = if (node.token.tag == .func) blk: {
        inline for (ctx.functions) |f| {
            if (comptime std.mem.eql(u8, f[0], node.token.str)) break :blk f[1];
        } else @compileError("Function not in context: " ++ node.token.str);
    } else blk: {
        inline for (ctx.ops) |l| {
            inline for (l) |o| {
                if (comptime std.mem.eql(u8, o[0], node.token.str)) break :blk o[1];
            }
        } else @compileError("Operator not in context: " ++ node.token.str);
    };

    comptime var args: std.meta.ArgsTuple(@TypeOf(func)) = undefined;
    inline for (node.data, 0..) |arg, i| {
        args[i] = comptime evaluate(@TypeOf(args[i]), arg, ctx);
    }
    return @call(.compile_time, func, args);
}
