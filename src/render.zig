const std = @import("std");
const gl = @import("gl");

pub const ghost_vertex = @embedFile("shaders/ghost.vert");
pub const ghost_fragment = @embedFile("shaders/ghost.frag");
pub const pumpkin_vertex = @embedFile("shaders/pumpkin.vert");
pub const pumpkin_fragment = @embedFile("shaders/pumpkin.frag");

const triangle_vertices = [_]f32{ -0.1, -0.1, 0.0, 0.1, -0.1, 0.0, 0.0, 0.1, 0.0 };
const triangle_uvs = [_]f32{ 0.0, 0.0, 1.0, 0.0, 0.5, 1.0 };

pub const RenderableEffect = struct {
    vertex_array: c_uint,
    vertex_buffer: c_uint,
    uv_buffer: c_uint,
    offset_buffer: c_uint,
    offsets: std.ArrayList(f32),

    pub fn init(allocator: std.mem.Allocator) !RenderableEffect {
        var vbo: c_uint = undefined;
        var vao: c_uint = undefined;

        gl.GenVertexArrays(1, @ptrCast(&vao));

        gl.GenBuffers(1, @ptrCast(&vbo));

        gl.BindVertexArray(vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        const vertices_len: isize = @intCast(triangle_vertices.len);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices_len, @ptrCast(&triangle_vertices), gl.STATIC_DRAW);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        var uv_buffer: c_uint = undefined;
        gl.GenBuffers(1, @ptrCast(&uv_buffer));
        gl.BindBuffer(gl.ARRAY_BUFFER, uv_buffer);

        const uv_len: isize = @intCast(triangle_uvs.len);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * uv_len, @ptrCast(&triangle_uvs), gl.STATIC_DRAW);
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, 0);
        gl.EnableVertexAttribArray(1);

        const offsets = try std.ArrayList(f32).initCapacity(allocator, 400); // cap to 200 effects per type to avoid reallocation

        var offset_buffer: c_uint = undefined;
        gl.GenBuffers(1, @ptrCast(&offset_buffer));
        gl.BindBuffer(gl.ARRAY_BUFFER, offset_buffer);
        gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), 0);
        gl.VertexAttribDivisor(2, 1);
        gl.EnableVertexAttribArray(2);

        return RenderableEffect{
            .vertex_array = vao,
            .vertex_buffer = vbo,
            .uv_buffer = uv_buffer,
            .offset_buffer = offset_buffer,
            .offsets = offsets,
        };
    }

    pub fn add(self: *RenderableEffect, x: f32, y: f32) !void {
        try self.offsets.append(x);
        try self.offsets.append(y);
    }

    pub fn clear(self: *RenderableEffect) void {
        self.offsets.clearRetainingCapacity();
    }

    pub fn renderInstanced(self: *RenderableEffect, program: *const RenderProgram) void {
        program.use();
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.BindVertexArray(self.vertex_array);
        const offsets_len: isize = @intCast(self.offsets.items.len);
        gl.BindBuffer(gl.ARRAY_BUFFER, self.offset_buffer);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * offsets_len, (self.offsets.items.ptr), gl.STATIC_DRAW);
        gl.DrawArraysInstanced(gl.TRIANGLES, 0, 3, @intCast(self.offsets.items.len / 2));
    }

    pub fn deinit(self: *RenderableEffect) void {
        self.offsets.deinit();
        gl.DeleteVertexArrays(1, @ptrCast(&self.vertex_array));
        gl.DeleteBuffers(1, @ptrCast(&self.vertex_buffer));
        gl.DeleteBuffers(1, @ptrCast(&self.offset_buffer));
        gl.DeleteBuffers(1, @ptrCast(&self.uv_buffer));
    }
};

pub const RenderProgram = struct {
    vertex_shader: c_uint,
    fragment_shader: c_uint,
    program: c_uint,

    pub fn init(vertex_shader: []const u8, fragment_shader: []const u8) !RenderProgram {
        const v = try compileShader(vertex_shader, gl.VERTEX_SHADER);
        errdefer gl.DeleteShader(v);
        const f = try compileShader(fragment_shader, gl.FRAGMENT_SHADER);
        errdefer gl.DeleteShader(f);

        const p = gl.CreateProgram();
        gl.AttachShader(p, v);
        gl.AttachShader(p, f);
        gl.LinkProgram(p);

        var success: c_int = undefined;
        gl.GetProgramiv(p, gl.LINK_STATUS, &success);
        if (success == 0) {
            var log: [512]u8 = [_]u8{0} ** 512;
            var length: c_int = undefined;
            gl.GetProgramInfoLog(p, log.len, &length, &log);
            std.debug.print("{s}", .{log});
            return error.ProgramLinkError;
        }

        return RenderProgram{
            .vertex_shader = v,
            .fragment_shader = f,
            .program = p,
        };
    }

    pub fn use(self: *const RenderProgram) void {
        gl.UseProgram(self.program);
    }

    pub fn deinit(self: *RenderProgram) void {
        gl.DeleteShader(self.vertex_shader);
        gl.DeleteShader(self.fragment_shader);
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
        std.debug.print("{s}", .{infoLog});
        gl.DeleteShader(shader);
        return error.shaderCompileError;
    }

    return shader;
}
