const std = @import("std");
const ascii = std.ascii;
const fmt = std.fmt;

pub fn main() void {
    // Check out potential Zig issue that discusses
    // concatenating structs using ++
    // Would be possible to create context structs, then
    // bundle a variables struct in with it as/when needed
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
    std.debug.print("\n", .{});

    comptime var p = Parser{ .tokens = tokens };
    comptime var tree: Node = p.parse(context);

    print_tree(tree, 0);
    std.debug.print("\n", .{});
}

const Token = struct {
    tag: Tag,
    str: []const u8,

    const Tag = enum { int, float, func, ident, op };

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

            if (ascii.isWhitespace(c)) {
                t.idx += 1;
                continue;
            }

            tokens = tokens ++ switch (c) {
                '0'...'9' => blk: {
                    const integral = slice_using(t, ascii.isDigit);
                    if (t.idx < t.expr.len and t.expr[t.idx] != '.') {
                        break :blk .{Token.init(.int, integral)};
                    } else {
                        t.idx += 1;
                        const fractional = slice_using(t, ascii.isDigit);
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
                    if (ascii.isPrint(c)) {
                        const op = slice_using(t, is_part_operator);
                        break :blk .{Token.init(.op, op)};
                    } else {
                        @compileError("Invalid character in expression: " ++
                            t.expr[t.idx .. t.idx + 1]);
                    }
                },
            };
        }
        return tokens;
    }

    fn slice_using(self: *Tokenizer, p: *const fn (c: u8) bool) []const u8 {
        var start: usize = self.idx;
        while (self.idx < self.expr.len and p(self.expr[self.idx])) self.idx += 1;
        return self.expr[start..self.idx];
    }

    fn is_part_identifier(c: u8) bool {
        return c == '_' or ascii.isAlphabetic(c) or ascii.isDigit(c);
    }

    fn is_part_operator(c: u8) bool {
        for ("!#$%&*+-./:;<=>?@[\\]^`|~") |s| if (c == s) return true;
        return false;
    }
};

const Node = struct {
    token: *const Token,
    tag: Tag,
    data: []const Node,

    const Tag = enum { leaf, unary, binary, arglist };

    fn init(token: *const Token, tag: Tag, data: []const Node) Node {
        return Node{ .token = token, .tag = tag, .data = data };
    }
};

const Parser = struct {
    tokens: []const Token,
    idx: usize = 0,

    // Include precedence level as part of the tuple
    // Simplifies the context struct
    // Can check the prec level when parsing

    fn parse(comptime p: *Parser, comptime context: anytype) Node {
        const tree: Node = parse_prec3(p, context);
        //if (!inbounds(p)) @compileError("Unexpected token in expression\n");
        return tree;
    }

    fn parse_prec3(p: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec2(p, context);
        comptime var tkn: *const Token = &p.tokens[p.idx];

        while (tkn.tag == .op and has_key(context.prec3, tkn.str)) {
            p.idx += 1;
            node = Node.init(tkn, .binary, &[_]Node{ node, parse_prec2(p, context) });
            tkn = &p.tokens[p.idx];
        }
        return node;
    }

    fn parse_prec2(p: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec1(p, context);
        comptime var tkn: *const Token = &p.tokens[p.idx];

        while (tkn.tag == .op and has_key(context.prec2, tkn.str)) {
            p.idx += 1;
            node = Node.init(tkn, .binary, &[_]Node{ node, parse_prec1(p, context) });
            tkn = &p.tokens[p.idx];
        }
        return node;
    }

    fn parse_prec1(p: *Parser, context: anytype) Node {
        const tkn: *const Token = &p.tokens[p.idx];

        if (tkn.tag == .op and has_key(context.prec1, tkn.str)) {
            p.idx += 1;
            return Node.init(tkn, .unary, &[_]Node{parse_prec1(p, context)});
        }
        return parse_prec0(p, context);
    }

    fn parse_prec0(p: *Parser, context: anytype) Node {
        const tkn: *const Token = &p.tokens[p.idx];

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

            while (inbounds(p) and !is_symbol(p, ')')) {
                if (is_symbol(p, ',')) {
                    p.idx += 1;
                    continue;
                }
                args = args ++ .{parse_prec3(p, context)};
            }

            if (!is_symbol(p, ')')) @compileError("Error: missing ')'\n");
            return Node.init(tkn, .arglist, args);
        }

        // Need to check if token is in variables or constants
        p.idx += 1;
        return Node.init(tkn, .leaf, &[_]Node{});
    }

    fn has_key(arr: anytype, key: []const u8) bool {
        for (arr) |pair| if (comptime std.mem.eql(u8, pair[0], key)) return true;
        return false;
    }

    fn is_symbol(self: *Parser, symbol: u8) bool {
        return self.tokens[self.idx].str[0] == symbol;
    }

    fn inbounds(self: *Parser) bool {
        return self.idx < self.tokens.len;
    }
};

fn evaluate(comptime T: anytype, node: Node, ctx: anytype) !T {
    if (node.data.len == 0 and node.token.tag != .func) {
        switch (node.token.tag) {
            .int => return fmt.parseInt(comptime_int, node.token.str, 10),
            .float => return fmt.parseFloat(comptime_float, node.token.str),
            .ident => {
                if (get_value_type(ctx.constants, node.token.str)) |vt| {
                    return get_value(vt, ctx.constants, node.token.str);
                }
            },
            else => unreachable,
        }
    }

    comptime var args = &.{};
    for (node.data) |arg| args = args ++ evaluate(arg);
    //const func = get func
    //return try @call()
}

fn get_value_type(comptime tuple: anytype, comptime key: []const u8) ?type {
    for (tuple) |pair| {
        if (std.mem.eql(u8, key, pair[0])) return @TypeOf(pair[1]);
    }
    return null;
}

// See if I can get value directly without needing type first
fn get_value(comptime T: anytype, tuple: anytype, key: []const u8) T {
    for (tuple) |pair| {
        if (std.mem.eql(u8, key, pair[0])) return pair[1];
    }
    @compileError("Key not found");
}

// Debug functions
fn print_tokens(ts: []const Token) void {
    for (ts) |t| std.debug.print("{s} [{s}]\n", .{ t.str, @tagName(t.tag) });
}

fn print_tree(n: Node, i: usize) void {
    for (0..i) |_| std.debug.print("   ", .{});
    std.debug.print(
        "{s} [{s} : {s}]\n",
        .{ n.token.str, @tagName(n.tag), @tagName(n.token.tag) },
    );
    for (n.data) |d| print_tree(d, i + 1);
}
