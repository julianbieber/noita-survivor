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

const vertexShaderSource = @embedFile("shaders/triangle.vert");

const fragmentShaderSource = @embedFile("shaders/triangle.frag");

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

    var triangle = try Renderable.init(vertexShaderSource, fragmentShaderSource);
    defer triangle.deinit();

    const vertices = [9]f32{ -0.5, -0.5, 0.0, 0.5, -0.5, 0.0, 0.0, 0.5, 0.0 };
    var VBO: c_uint = undefined;
    var VAO: c_uint = undefined;

    gl.GenVertexArrays(1, @ptrCast(&VAO));
    defer gl.DeleteVertexArrays(1, @ptrCast(&VAO));

    gl.GenBuffers(1, @ptrCast(&VBO));
    defer gl.DeleteBuffers(1, @ptrCast(&VBO));

    // bind the Vertex Array Object first, then bind and set vertex buffer(s), and then configure vertex attributes(s).
    gl.BindVertexArray(VAO);
    gl.BindBuffer(gl.ARRAY_BUFFER, VBO);
    // Fill our buffer with the vertex data
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

    // Specify and link our vertext attribute description
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);

    const startTime = std.time.nanoTimestamp();
    while (c.glfwWindowShouldClose(window) != 1) {
        const since: i128 = std.time.nanoTimestamp() - startTime;
        var sinceF: f32 = @floatFromInt(since);
        sinceF = sinceF / 1000000000.0;
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // Activate shaderProgram
        gl.UseProgram(triangle.program);
        gl.Uniform1f(triangle.timeUniform, sinceF);
        gl.BindVertexArray(VAO); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        gl.DrawArraysInstanced(gl.TRIANGLES, 0, 3, 600);
        // gl.DrawArrays(gl.TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }
}

const Renderable = struct {
    vertexShader: c_uint,
    fragmentShader: c_uint,
    program: c_uint,
    timeUniform: c_int, // TODO replace with hashmap

    fn init(vertexShader: []const u8, fragmentShader: []const u8) !Renderable {
        const v = try compileShader(vertexShader, gl.VERTEX_SHADER);
        const f = try compileShader(fragmentShader, gl.FRAGMENT_SHADER); // TODO deinit vertex shader on error

        const p = gl.CreateProgram();
        gl.AttachShader(p, v);
        gl.AttachShader(p, f);
        gl.LinkProgram(p);
        const timeUniform = gl.GetUniformLocation(p, "time");

        var success: c_int = undefined;
        gl.GetProgramiv(p, gl.LINK_STATUS, &success);
        if (success == 0) {
            var log: [512]u8 = [_]u8{0} ** 512;
            var length: c_int = undefined;
            gl.GetProgramInfoLog(p, log.len, &length, &log);
            std.log.err("{s}", .{log});
            // TODO deinit program and shaders;
            return error.ProgramLinkError;
        }

        return Renderable{
            .vertexShader = v,
            .fragmentShader = f,
            .program = p,
            .timeUniform = timeUniform,
        };
    }

    fn deinit(self: *Renderable) void {
        gl.DeleteShader(self.vertexShader);
        gl.DeleteShader(self.fragmentShader);
        gl.DeleteProgram(self.program);
    }
};

fn compileShader(source: []const u8, shader_type: c_uint) !c_uint {
    const shader = gl.CreateShader(shader_type);
    gl.ShaderSource(shader, 1, @ptrCast(&source), &[_]c_int{@intCast(source.len)});
    gl.CompileShader(shader);
    var success: c_int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        var infoLog: [512]u8 = [_]u8{0} ** 512;
        var length: c_int = undefined;
        gl.GetShaderInfoLog(shader, infoLog.len, &length, &infoLog);
        std.log.err("{s}", .{infoLog});
        gl.DeleteShader(shader);
        return error.shaderCompileError;
    }

    return shader;
}
