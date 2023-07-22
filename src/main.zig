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
        std.debug.print("{s} : {}\n", .{ @tagName(tkn), tkn });
    }
}

// Does this need to be tagged?
const Token = union(enum) {
    integer: []const u8,
    float: []const u8,
    function: []const u8,
    variable: []const u8,
    operator: []const u8,
};

const Tokenizer = struct {
    expr: []const u8 = undefined,
    index: usize = 0,

    pub fn tokenize(self: *Tokenizer, comptime expr: []const u8) []const Token {
        var tokens: []const Token = &.{};
        self.expr = expr;

        inline while (self.index < self.expr.len) {
            switch (self.expr[self.index]) {
                ' ', '\t', '\n', '\r' => self.index += 1,
                '0'...'9' => {
                    const integral = slice_using(self, ascii.isDigit);
                    if (self.index == self.expr.len or self.expr[self.index] != '.') {
                        tokens = tokens ++ .{Token{ .integer = integral }};
                    } else {
                        self.index += 1;
                        const fractional = slice_using(self, ascii.isDigit);
                        tokens = tokens ++ .{Token{ .float = integral ++ "." ++ fractional }};
                    }
                },
                '_', 'a'...'z', 'A'...'Z' => {
                    const ident = slice_using(self, is_part_identifier);
                    if (self.index != self.expr.len and self.expr[self.index] == '(') {
                        tokens = tokens ++ .{Token{ .function = ident }};
                    } else {
                        tokens = tokens ++ .{Token{ .variable = ident }};
                    }
                },
                else => {
                    if (ascii.isPrint(self.expr[self.index])) {
                        const op = slice_using(self, is_part_operator);
                        tokens = tokens ++ .{Token{ .operator = op }};
                    } else {
                        @compileError("Invalid character in expression: " ++
                            self.expr[self.index .. self.index + 1] + "\n");
                    }
                },
            }
        }
        return tokens;
    }

    fn slice_using(self: *Tokenizer, pred: *const fn (c: u8) bool) []const u8 {
        var start: usize = self.index;
        while (self.index < self.expr.len and pred(self.expr[self.index])) {
            self.index += 1;
        }
        return self.expr[start..self.index];
    }

    fn is_part_identifier(c: u8) bool {
        return c == '_' or ascii.isAlphabetic(c) or ascii.isDigit(c);
    }

    fn is_part_operator(c: u8) bool {
        return ascii.isPrint(c) and !ascii.isWhitespace(c);
    }
};
