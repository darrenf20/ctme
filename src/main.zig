const std = @import("std");
const ascii = std.ascii;

pub fn main() void {
    // Check out potential Zig issue that discusses
    // concatenating structs using ++
    // Would be possible to create context structs, then
    // bundle a variables struct in with it as/when needed
    const context = .{
        .constants = .{},

        .functions = .{},

        .operators = .{},
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
                    const char = self.expr[self.idx .. self.idx + 1];
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
    token: *Token,
    ntype: Node_Type,
    data: []Node,

    const Node_Type = enum { leaf, unary, binary, arglist };

    fn init(token: *Token, ntype: Node_Type, data: []Node) Node {
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
        return tree;
    }

    fn parse_prec3(self: *Parser, context: anytype) Node {
        var node: Node = parse_prec2(self, context);
        var tkn: Token = self.tokens[self.idx];
        while (tkn.ttype == .operator and has_key(context.prec3, tkn.string)) {
            self.idx += 1;
            node = Node.init(&tkn, .binary, .{ node, parse_prec2(self, context) });
        }
        return node;
    }

    fn parse_prec2(self: *Parser, context: anytype) Node {
        var node: Node = parse_prec1(self, context);
        var tkn: Token = self.tokens[self.idx];
        while (tkn.ttype == .operator and has_key(context.prec2, tkn.string)) {
            self.idx += 1;
            node = Node.init(&tkn, .binary, &.{ node, parse_prec1(self, context) });
        }
        return node;
    }

    fn parse_prec1(self: *Parser, context: anytype) Node {
        var tkn: Token = self.tokens[self.idx];
        if (tkn.ttype == .operator and has_key(context.prec1, tkn.string)) {
            self.idx += 1;
            return Node.init(&tkn, .unary, &.{parse_prec1(self, context)});
        }
        return parse_prec0(self, context);
    }

    fn parse_prec0(self: *Parser, context: anytype) Node {
        var tkn: Token = self.tokens[self.idx];

        if (is_symbol(self, '(')) {
            self.idx += 1;
            var node: Node = parse_prec3(self, context);

            if (!is_symbol(self, ')')) @compileError("Error: missing ')'\n");

            return node;
        }

        if (tkn.ttype == .function and has_key(context.functions, tkn.string)) {
            self.idx += 2;
            var args: []Node = &.{};

            while (self.idx < self.tokens.len and !is_symbol(self, ')')) {
                if (is_symbol(self, ',')) continue;
                args = args ++ .{parse_prec3(self, context)};
                self.idx += 1;
            }

            if (!is_symbol(self, ')')) @compileError("Error: missing ')'\n");

            return Node.init(&tkn, .arglist, args);
        }
        return Node.init(&tkn, .leaf, &.{});
    }

    fn has_key(arr: anytype, key: []const u8) bool {
        for (arr) |pair| if (comptime std.mem.eql(u8, pair[0], key)) return true;
        return false;
    }

    fn is_symbol(self: *Parser, c: u8) bool {
        return self.tokens[self.idx].string[0] == c;
    }

    // need a func for getting next token, because I have to do a
    // bounds check (self.idx < self.tokens.len)
};
