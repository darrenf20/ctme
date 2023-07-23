const std = @import("std");
const ascii = std.ascii;

pub fn main() void {
    calc("   ding + 42.069 * (a - 7) / sin(5 + 2)");
}

// context: anytype, variables: anytype
pub fn calc(comptime expression: []const u8) void {
    comptime var t = Tokenizer{};
    comptime var tokens: []const Token = t.tokenize(expression);

    for (tokens) |tkn| {
        std.debug.print("{} : {s}\n", .{ tkn.ttype, tkn.string });
    }
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

const AST_Node = struct {
    // Maybe stick with Token, and have parser construct the AST,
    // and parsing done at evaluation phase
    // Partial AST evaluation at phase 2 seems difficult/complicated
    value: Value,
    lnode: *AST_Node,
    rnode: *AST_Node,

    const Value = union(enum) {
        integer: i128,
        float: f128,
        function,
        variable,
        operator,
        lparen,
        rparen,
        comma,
    };

    fn init(value: Value, left: *AST_Node, right: *AST_Node) AST_Node {
        return AST_Node{ .value = value, .lnode = left, .rnode = right };
    }
};
