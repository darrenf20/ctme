# CTME
### Compile-Time Mathematics Evaluator

This module implements a recursive descent parser, allowing users to write strings representing mathematical expressions that can be evaluated with user-defined context structs.

### Motivation
Since Zig does not allow operator-overloading, many programmers find writing linear algebra expressions verbose or difficult. Using this module, users could write a context struct for linear algebra operators that can be used to evaluate the result of a string representing a linear algebra calculation.

Please see `src/main.zig` for an example.

### Installation
- Dependencies: [Zig](https://ziglang.org/download/), git
- Clone this repo into your desired directory
- Type `zig build run`

### Current limitations:
- Operators within a context must be unique
- Only working on floating point numbers
- Custom functions need to be created for each operator
- Lacks validation and error checking
- No custom associativity (left-associative by default)
