// YOU ARE ON NOPTR BRANCH
// REMEMBER TO SWITCH BACK WHEN DONE
const std = @import("std");
const ascii = std.ascii;

pub fn main() void {
    // Check out potential Zig issue that discusses
    // concatenating structs using ++
    // Would be possible to create context structs, then
    // bundle a variables struct in with it as/when needed
    const context = .{
        .constants = .{
            .{ "ding", 360 },
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
    comptime var t = Tokenizer{};
    comptime var tokens: []const Token = t.tokenize(expression);

    //for (tokens) |tkn| {
    //    std.debug.print("{} : {s}\n", .{ tkn.ttype, tkn.string });
    //}

    comptime var p = Parser{};
    comptime var tree: Node = p.parse(tokens, context);

    //print_tree(tree, 0);
    _ = tree;
}

const Token = struct {
    ttype: Token_Type,
    string: []const u8,

    const Token_Type = enum { integer, float, function, variable, operator };

    fn init(ttype: Token_Type, string: []const u8) Token {
        return Token{ .ttype = ttype, .string = string };
    }
};

const Tokenizer = struct {
    expr: []const u8 = undefined,
    idx: usize = 0,

    fn tokenize(self: *Tokenizer, comptime expr: []const u8) []const Token {
        var tokens: []const Token = &.{};
        self.expr = expr;

        inline while (self.idx < self.expr.len) {
            const c = self.expr[self.idx];

            if (ascii.isWhitespace(c)) {
                self.idx += 1;
                continue;
            }

            tokens = tokens ++ switch (c) {
                '0'...'9' => blk: {
                    const integral = slice_using(self, ascii.isDigit);
                    if (self.idx < self.expr.len and self.expr[self.idx] != '.') {
                        break :blk .{Token.init(.integer, integral)};
                    } else {
                        self.idx += 1;
                        const fractional = slice_using(self, ascii.isDigit);
                        const decimal = integral ++ "." ++ fractional;
                        break :blk .{Token.init(.float, decimal)};
                    }
                },
                '_', 'a'...'z', 'A'...'Z' => blk: {
                    const ident = slice_using(self, is_part_identifier);
                    if (self.idx < self.expr.len and self.expr[self.idx] == '(') {
                        break :blk .{Token.init(.function, ident)};
                    } else {
                        break :blk .{Token.init(.variable, ident)};
                    }
                },
                '(', ')', ',' => blk: {
                    // Another way to get slice of single char?
                    const char = self.expr[self.idx .. self.idx + 1]; // &self.expr[self.idx] ?
                    self.idx += 1;
                    break :blk .{Token.init(.operator, char)};
                },
                else => blk: {
                    if (ascii.isPrint(c)) {
                        const op = slice_using(self, is_part_operator);
                        break :blk .{Token.init(.operator, op)};
                    } else {
                        @compileError("Invalid character in expression: " ++
                            self.expr[self.idx .. self.idx + 1] + "\n");
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
    ntype: Node_Type,
    data: []const Node,

    const Node_Type = enum { leaf, unary, binary, arglist };

    fn init(token: *const Token, ntype: Node_Type, data: []const Node) Node {
        return Node{ .token = token, .ntype = ntype, .data = data };
    }
};

const Parser = struct {
    tokens: []const Token = undefined,
    idx: usize = 0,

    fn parse(
        self: *Parser,
        comptime tokens: []const Token,
        comptime context: anytype,
    ) Node {
        self.tokens = tokens;
        const tree: Node = parse_prec3(self, context);
        if (self.idx != self.tokens.len) @compileError("Unexpected token in expression\n");
        return tree;
    }

    fn parse_prec3(self: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec2(self, context);
        comptime var tkn: Token = self.tokens[self.idx];
        while (tkn.ttype == .operator and has_key(context.prec3, tkn.string)) {
            self.idx += 1;
            node = Node.init(&tkn, .binary, &[_]Node{ node, parse_prec2(self, context) });
            tkn = self.tokens[self.idx];
        }
        return node;
    }

    fn parse_prec2(self: *Parser, context: anytype) Node {
        comptime var node: Node = parse_prec1(self, context);
        comptime var tkn: Token = self.tokens[self.idx];
        while (tkn.ttype == .operator and has_key(context.prec2, tkn.string)) {
            self.idx += 1;
            node = Node.init(&tkn, .binary, &[_]Node{ node, parse_prec1(self, context) });
            tkn = self.tokens[self.idx];
        }
        return node;
    }

    fn parse_prec1(self: *Parser, context: anytype) Node {
        check_index(self);
        const tkn: Token = self.tokens[self.idx];

        if (tkn.ttype == .operator and has_key(context.prec1, tkn.string)) {
            self.idx += 1;
            return Node.init(&tkn, .unary, &[_]Node{parse_prec1(self, context)});
        }
        return parse_prec0(self, context);
    }

    fn parse_prec0(self: *Parser, context: anytype) Node {
        check_index(self);
        const tkn: Token = self.tokens[self.idx];

        if (is_symbol(self, '(')) {
            self.idx += 1;
            const node: Node = parse_prec3(self, context);
            if (!is_symbol(self, ')')) @compileError("Error: missing ')'\n");
            return node;
        }

        if (tkn.ttype == .function and has_key(context.functions, tkn.string)) {
            self.idx += 2;
            comptime var args = [_]Node{};

            while (self.idx < self.tokens.len and !is_symbol(self, ')')) {
                if (is_symbol(self, ',')) continue;
                args = args ++ .{parse_prec3(self, context)};
                self.idx += 1;
            }

            if (!is_symbol(self, ')')) @compileError("Error: missing ')'\n");

            return Node.init(&tkn, .arglist, args);
        }

        // Need to check if token is in variables or constants
        self.idx += 1;
        return Node.init(&tkn, .leaf, &[_]Node{});
    }

    fn has_key(arr: anytype, key: []const u8) bool {
        for (arr) |pair| if (comptime std.mem.eql(u8, pair[0], key)) return true;
        return false;
    }

    fn is_symbol(self: *Parser, c: u8) bool {
        return self.tokens[self.idx].string[0] == c;
    }

    fn check_index(self: *Parser) void {
        if (self.idx >= self.tokens.len) @compileError("Reached end of tokens\n");
    }
};

fn print_tree(n: *const Node, i: usize) void {
    for (0..i) |_| std.debug.print("   ", .{});
    std.debug.print(
        "{s} ({s} : {s})\n",
        .{ n.token.string, @tagName(n.ntype), @tagName(n.token.ttype) },
    );
    for (n.data) |d| print_tree(d, i + 1);
    //std.debug.print("\n", .{});
}
