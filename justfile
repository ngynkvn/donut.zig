default *args:
    zig build run --summary all -- {{args}}

test:
    zig build test --summary all

check:
    zig build check --summary all

list:
    @just --list
