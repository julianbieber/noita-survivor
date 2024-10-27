const std = @import("std");
const print = std.debug.print;
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const Player = @This();

const Direction = enum {
    left,
    right,
    up,
    down,
};

var direction = Direction.right;

pub fn keyboardCallback(_: ?*c.GLFWwindow, key: c_int, _: c_int, _: c_int, _: c_int) callconv(.C) void {
    switch (key) {
        c.GLFW_KEY_W, c.GLFW_KEY_UP => {
            direction = Direction.up;
        },
        c.GLFW_KEY_S, c.GLFW_KEY_DOWN => {
            direction = Direction.down;
        },
        c.GLFW_KEY_A, c.GLFW_KEY_LEFT => {
            direction = Direction.left;
        },
        c.GLFW_KEY_D, c.GLFW_KEY_RIGHT => {
            direction = Direction.right;
        },
        else => {},
    }

    // print("player direction: {s}\n", .{@tagName(direction)});
}
