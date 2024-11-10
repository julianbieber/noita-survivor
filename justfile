build:
    zig build -Doptimize=ReleaseFast
buildSafe:
    zig build -Doptimize=ReleaseSafe


run: build
    ./zig-out/bin/noita-survivor

runSafe: buildSafe
    ./zig-out/bin/noita-survivor
