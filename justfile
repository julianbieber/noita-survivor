build:
    zig build -Doptimize=ReleaseFast


run: build
    ./zig-out/bin/noita-survivor
