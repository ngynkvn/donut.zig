# donut.zig


https://github.com/user-attachments/assets/5f3c80c9-774c-4c6b-bc88-f59e0c759536


It's a spinning donut in the terminal! (Running in Wezterm and Kitty above)

My take on [Andy Sloane's excellent article](https://www.a1k0n.net/2011/07/20/donut-math.html) using braille characters as a plotting device for the terminal.

## Build and run

Requires Zig 0.16.0 and a terminal with braille character support.

```sh
zig build
zig build run
zig build test
zig build check
zig build bench -Doptimize=ReleaseFast
```

The benchmark measures 2,000 animation frames at 80×24 without terminal I/O or frame pacing, reporting rendering time and emitted bytes per frame.

## Preface

Code is kind of buggy. This was my first "project" in zig
