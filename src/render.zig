const std = @import("std");
const gl = @import("gl");

pub const ghost_vertex = @embedFile("shaders/ghost.vert");
pub const ghost_fragment = @embedFile("shaders/ghost.frag");
pub const pumpkin_vertex = @embedFile("shaders/pumpkin.vert");
pub const pumpkin_fragment = @embedFile("shaders/pumpkin.frag");
pub const explosion_vertex = @embedFile("shaders/explosion.vert");
pub const explosion_fragment = @embedFile("shaders/explosion.frag");

const triangle_vertices = [_]f32{ -0.1, -0.1, 0.0, 0.1, -0.1, 0.0, 0.0, 0.1, 0.0 };
const triangle_uvs = [_]f32{ 0.0, 0.0, 1.0, 0.0, 0.5, 1.0 };

// -+2 ++X
// --0 +-1
// -+2 ++1
// --X +-0
const cube_vertices = [_]f32{
    -0.1, -0.1, 0.0,
    0.1,  -0.1, 0.0,
    -0.1, 0.1,  0.0,
    0.1,  -0.1, 0.0,
    0.1,  0.1,  0.0,
    -0.1, 0.1,  0.0,
};
const cube_uvs = [_]f32{
    0.0, 0.0,
    1.0, 0.0,
    0.0, 1.0,
    1.0, 0.0,
    1.0, 1.0,
    0.0, 1.0,
};

pub const BufferDescriptor = struct {
    size_per_element: usize,
    stride: usize,
};

pub const RenderableEffect = struct {
    vertex_array: c_uint,
    vertex_buffer: c_uint,
    uv_buffer: c_uint,
    buffers: std.ArrayList(c_uint),
    buffer_contents: std.ArrayList(std.ArrayList(f32)),
    buffer_descriptors: std.ArrayList(BufferDescriptor),

    pub fn init(allocator: std.mem.Allocator, buffer_descriptors: []const BufferDescriptor) std.mem.Allocator.Error!RenderableEffect {
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

        var buffers = std.ArrayList(c_uint).init(allocator);
        var buffer_contents = std.ArrayList(std.ArrayList(f32)).init(allocator);
        for (buffer_descriptors, 2..) |bc, i| {
            var b: c_uint = undefined;

            gl.GenBuffers(1, @ptrCast(&b));
            gl.BindBuffer(gl.ARRAY_BUFFER, b);
            gl.VertexAttribPointer(@intCast(i), @intCast(bc.size_per_element), gl.FLOAT, gl.FALSE, @intCast(bc.stride), 0);
            gl.VertexAttribDivisor(@intCast(i), 1);
            gl.EnableVertexAttribArray(@intCast(i));
            try buffers.append(b);
            try buffer_contents.append(std.ArrayList(f32).init(allocator));
        }

        var owned_buffer_descriptors = std.ArrayList(BufferDescriptor).init(allocator);
        try owned_buffer_descriptors.appendSlice(buffer_descriptors);

        return RenderableEffect{
            .vertex_array = vao,
            .vertex_buffer = vbo,
            .uv_buffer = uv_buffer,
            .buffers = buffers,
            .buffer_contents = buffer_contents,
            .buffer_descriptors = owned_buffer_descriptors,
        };
    }

    pub fn init_cube(allocator: std.mem.Allocator, buffer_descriptors: []const BufferDescriptor) std.mem.Allocator.Error!RenderableEffect {
        var vbo: c_uint = undefined;
        var vao: c_uint = undefined;

        gl.GenVertexArrays(1, @ptrCast(&vao));

        gl.GenBuffers(1, @ptrCast(&vbo));

        gl.BindVertexArray(vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        const vertices_len: isize = @intCast(cube_vertices.len);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices_len, @ptrCast(&cube_vertices), gl.STATIC_DRAW);
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        var uv_buffer: c_uint = undefined;
        gl.GenBuffers(1, @ptrCast(&uv_buffer));
        gl.BindBuffer(gl.ARRAY_BUFFER, uv_buffer);

        const uv_len: isize = @intCast(cube_uvs.len);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * uv_len, @ptrCast(&cube_uvs), gl.STATIC_DRAW);
        gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 0, 0);
        gl.EnableVertexAttribArray(1);

        var buffers = std.ArrayList(c_uint).init(allocator);
        var buffer_contents = std.ArrayList(std.ArrayList(f32)).init(allocator);
        for (buffer_descriptors, 2..) |bc, i| {
            var b: c_uint = undefined;

            gl.GenBuffers(1, @ptrCast(&b));
            gl.BindBuffer(gl.ARRAY_BUFFER, b);
            gl.VertexAttribPointer(@intCast(i), @intCast(bc.size_per_element), gl.FLOAT, gl.FALSE, @intCast(bc.stride), 0);
            gl.VertexAttribDivisor(@intCast(i), 1);
            gl.EnableVertexAttribArray(@intCast(i));
            try buffers.append(b);
            try buffer_contents.append(std.ArrayList(f32).init(allocator));
        }

        var owned_buffer_descriptors = std.ArrayList(BufferDescriptor).init(allocator);
        try owned_buffer_descriptors.appendSlice(buffer_descriptors);

        return RenderableEffect{
            .vertex_array = vao,
            .vertex_buffer = vbo,
            .uv_buffer = uv_buffer,
            .buffers = buffers,
            .buffer_contents = buffer_contents,
            .buffer_descriptors = owned_buffer_descriptors,
        };
    }

    pub fn add(self: *RenderableEffect, buffer_index: usize, content: []const f32) !void {
        try self.buffer_contents.items[buffer_index].appendSlice(content);
    }

    pub fn clear(self: *RenderableEffect) void {
        for (self.buffer_contents.items) |*bc| {
            bc.clearRetainingCapacity();
        }
    }

    // refactor to not use vertex coutn as a parameter
    pub fn render_instanced(self: *RenderableEffect, program: *const RenderProgram, vertex_count: c_int) void {
        program.use();
        gl.Enable(gl.BLEND);
        gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.BindVertexArray(self.vertex_array);

        for (self.buffers.items, self.buffer_contents.items, self.buffer_descriptors.items) |b, bc, bd| {
            const offsets_len: isize = @intCast(bc.items.len);
            gl.BindBuffer(gl.ARRAY_BUFFER, b);
            gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * offsets_len, (bc.items.ptr), gl.STATIC_DRAW);
            gl.DrawArraysInstanced(gl.TRIANGLES, 0, vertex_count, @intCast(bc.items.len / bd.size_per_element)); // the divisor should depend on the buffer descriptor
        }
    }

    pub fn deinit(self: *RenderableEffect) void {
        gl.DeleteVertexArrays(1, @ptrCast(&self.vertex_array));
        gl.DeleteBuffers(1, @ptrCast(&self.vertex_buffer));
        gl.DeleteBuffers(1, @ptrCast(&self.uv_buffer));
        for (self.buffers.items) |*b| {
            gl.DeleteBuffers(1, @ptrCast(b));
        }
        self.buffers.deinit();

        for (self.buffer_contents.items) |bc| {
            bc.deinit();
        }

        self.buffer_contents.deinit();
        self.buffer_descriptors.deinit();
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
