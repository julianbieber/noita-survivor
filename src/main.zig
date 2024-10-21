const std = @import("std");
const gl = @import("gl");

const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

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

    const window = c.glfwCreateWindow(1920, 1200, "Hello World", null, null).?;
    defer c.glfwDestroyWindow(window);
    c.glfwMakeContextCurrent(window);
    defer c.glfwMakeContextCurrent(null);

    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferCallback);

    if (!gl.ProcTable.init(&procs, c.glfwGetProcAddress)) {
        return error.OpenGLProcTableFailed;
    }
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    while (c.glfwWindowShouldClose(window) != 1) {
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

const Renderable = struct {
    vertexShader: c_int,
    fragmentShader: c_int,
    program: c_int,

    fn init(vertexShader: [*:0]const u8, fragmentShader: [*:0]const u8) !Renderable {
        const v = try compileShader(vertexShader, gl.VERTEX_SHADER);
        const f = try compileShader(fragmentShader, gl.FRAGMENT_SHADER); // TODO deinit vertex shader on error

        const p = gl.CreateProgram();
        gl.AttachShader(p, v);
        gl.AttachShader(p, f);
        gl.LinkProgram(p);

        var success: c_int = undefined;
        gl.GetProgramiv(p, gl.LINK_STATUS, &success);
        if (success == 0) {
            var log: [512]u8 = [_]u8{0} ** 512;
            gl.GetProgramInfoLog(p, log.len, 0, &log);
            std.log.err("{s}", log);
            // TODO deinit program and shaders;
            return error.ProgramLinkError;
        }

        return Renderable{
            .vertexShader = v,
            .fragmentShader = f,
            .program = p,
        };
    }

    fn deinit(self: *Renderable) void {
        gl.DeleteShader(self.vertexShader);
        gl.DeleteShader(self.fragmentShader);
        gl.DeleteProgram(self.program);
    }
};

fn compileShader(source: [*:0]const u8, shader_type: c_int) !c_int {
    const shader = gl.CreateShader(shader_type);
    gl.ShaderSource(shader, 1, @ptrCast(source), [_]c_int{source.len});
    gl.CompileShader(shader);
    var success: c_int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        var infoLog: [512]u8 = [_]u8{0} ** 512;
        gl.GetShaderInfoLog(shader, infoLog.len, 0, &infoLog);
        std.log.err("{s}", infoLog);
        gl.DeleteShader(shader);
        return error.shaderCompileError;
    }

    return shader;
}
