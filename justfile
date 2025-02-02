build:
    zig build -Doptimize=ReleaseFast
buildSafe:
    zig build -Doptimize=ReleaseSafe
buildDebug:
    zig build

test:
    zig build test --summary all


run: build
    ./zig-out/bin/noita-survivor

runSafe: buildSafe
    ./zig-out/bin/noita-survivor

runDebug: buildDebug
    ./zig-out/bin/noita-survivor
    
