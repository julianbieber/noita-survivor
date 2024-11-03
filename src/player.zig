const std = @import("std");
const gl = @import("gl");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const print = std.debug.print;

pub const Player = @This();

const Direction = enum {
    left,
    right,
    up,
    down,
};

var direction = Direction.right;
var position = null;

pub fn keyboardCallback(window: ?*c.GLFWwindow, key: c_int, _: c_int, _: c_int, _: c_int) callconv(.C) void {
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
        c.GLFW_KEY_ESCAPE => {
            print("ESC pressed, closing window.\n", .{});

            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        },
        else => {},
    }
}

pub fn draw() void {}
