const std = @import("std");

const Calc_Error = error{Parse_Error};

const Token_Type = enum { Operator, Identifier, Number };

const Token = struct {
    ttype: Token_Type,
    value: []const u8,
};

const Lexer = struct {
    expr: []const u8,
    index: usize = 0,

    fn create_token(ttype: Token_Type, value: []const u8) Token {
        return Token{
            .ttype = ttype,
            .value = value,
        };
    }

    fn scan_with(self: *Lexer, f: *const fn (c: u8) bool) void {
        for (self.expr[self.index..]) |e| {
            if (!f(e)) break;
            self.index += 1;
        }
    }

    fn is_operator_part(c: u8) bool {
        const s = [_]u8{c};
        const symbols: []const u8 = "+-*/()^%=,";
        return if (std.ascii.indexOfIgnoreCase(symbols, &s)) |_| true else false;
    }

    fn scan_operator(self: *Lexer) ?Token {
        var c: u8 = self.expr[self.index];
        if (!is_operator_part(c)) return null;

        var a: usize = self.index;
        self.scan_with(is_operator_part);
        var b: usize = self.index;
        return create_token(Token_Type.Operator, self.expr[a..b]);
    }

    fn is_identifier_part(c: u8) bool {
        return std.ascii.isAlphabetic(c) or std.ascii.isDigit(c);
    }

    fn scan_identifier(self: *Lexer) ?Token {
        var c: u8 = self.expr[self.index];
        if (!std.ascii.isAlphabetic(c)) return null;

        var a: usize = self.index;
        self.scan_with(is_identifier_part);
        var b: usize = self.index;
        return create_token(Token_Type.Identifier, self.expr[a..b]);
    }

    fn scan_number(self: *Lexer) !?Token {
        var c: u8 = self.expr[self.index];
        if (!std.ascii.isDigit(c) and c != '.') return null;

        var a: usize = self.index;

        if (c != '.') self.scan_with(std.ascii.isDigit);

        if (c == '.') {
            self.index += 1;
            self.scan_with(std.ascii.isDigit);
        }

        if (c == 'e' or c == 'E') {
            self.index += 1;
            c = self.expr[self.index];

            if (c == '+' or c == '-' or std.ascii.isDigit(c)) {
                self.index += 1;
                self.scan_with(std.ascii.isDigit);
            } else {
                std.debug.print("Unexpected character after exponent sign\n", .{});
                return error.Calc_Error;
                // Check error printing and error return value, etc.
            }
        }

        var b: usize = self.index;

        if (std.ascii.eqlIgnoreCase(self.expr[a..b], ".")) {
            std.debug.print("Expecting digits after the dot sign\n", .{});
            return error.Parse_Error;
            // Check error printing and error return value, etc.
        }

        return create_token(Token_Type.Number, self.expr[a..b]);
    }

    pub fn reset(self: *Lexer, str: []u8) void {
        self.expr = str;
        self.index = 0;
    }

    pub fn next(self: *Lexer) !?Token {
        self.scan_with(std.ascii.isWhitespace); // skip spaces
        if (self.index >= self.expr.len) return null;

        var token: ?Token = try scan_number(self);
        if (token) |t| return t;

        token = scan_operator(self);
        if (token) |t| return t;

        token = scan_identifier(self);
        if (token) |t| return t;

        std.debug.print("Unknown token\n", .{});
        return error.Parse_Error;
    }

    pub fn peek(self: *Lexer) ?Token {
        var idx: usize = self.index;
        var token: ?Token = try next(self);
        self.index = idx;
        return token;
    }
};

pub fn main() !void {
    var expression: []const u8 = "x = -6 * 7";
    var lexer = Lexer{ .expr = expression };

    while (try lexer.next()) |t| {
        std.debug.print("{s} : {s}\n", .{ @tagName(t.ttype), t.value });
    }
}
