const std = @import("std");
const gl = @import("gl");
const World = @import("world.zig").World;

const player = @import("player.zig");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const log_level: std.log.Level = .info;

const assert = @import("std").debug.assert;

fn glfwErrorCallback(_: c_int, message: [*c]const u8) callconv(.C) void {
    std.debug.print("Error in callbakc {s}\n", .{message});
}

fn frameBufferCallback(_: ?*c.GLFWwindow, width: i32, height: i32) callconv(.C) void {
    gl.Viewport(0, 0, width, height);
}

var procs: gl.ProcTable = undefined;

pub fn main() !void {
    _ = c.glfwSetErrorCallback(glfwErrorCallback);
    const errorCode = c.glfwInit();
    if (errorCode != 1) {
        std.debug.print("Error code: {!}\n", .{errorCode});
        return error.InitFailed;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(1920, 1200, "Hello World", c.glfwGetPrimaryMonitor(), null).?;
    defer c.glfwDestroyWindow(window);
    c.glfwMakeContextCurrent(window);
    defer c.glfwMakeContextCurrent(null);

    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferCallback);

    if (!gl.ProcTable.init(&procs, c.glfwGetProcAddress)) {
        return error.OpenGLProcTableFailed;
    }
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinitstatus = gpa.deinit();
        if (deinitstatus == .leak) {
            @panic("Leak detected");
        }
    }
    var world = try World.init(allocator);
    defer world.deinit();

    _ = c.glfwSetKeyCallback(window, player.keyboardCallback);

    while (c.glfwWindowShouldClose(window) != 1) {
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        player.draw();
        try world.frame();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}
