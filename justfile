default *args:
    zig build run --summary all -- {{args}}

test:
    zig build test --summary all --prominent-compile-errors

check:
    zig build check --summary all

list:
    @just --list
