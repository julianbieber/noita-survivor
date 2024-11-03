const std = @import("std");
const gl = @import("gl");
const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

const render = @import("render.zig");
const spells = @import("spells.zig");

const print = std.debug.print;

var vertex_shader_source = @embedFile("shaders/player.vert");
var fragment_shader_source = @embedFile("shaders/player.frag");

const Direction = enum {
    left,
    right,
    up,
    down,
};

const PlayerState = struct {
    direction: Direction,
    position: spells.Vec2,
};

var player_state = PlayerState{
    .direction = Direction.right,
    .position = spells.Vec2{ .x = 0, .y = 0 },
};

pub const Player = struct {
    render_program: render.RenderProgram,
    vertex_buffer: c_uint,
    vertex_array: c_uint,
    element_buffer: c_uint,

    pub fn deinit(self: *Player) void {
        self.render_program.deinit();

        gl.DeleteVertexArrays(1, @ptrCast(&self.vertex_array));
        gl.DeleteBuffers(1, @ptrCast(&self.vertex_buffer));
        gl.DeleteBuffers(1, @ptrCast(&self.element_buffer));
    }

    pub fn init() !Player {
        const r = try render.RenderProgram.init(vertex_shader_source, fragment_shader_source);

        const vertices = [12]f32{
            0.5, 0.5, -0.1, // top right
            0.5, -0.5, -0.1, // bottom right
            -0.5, -0.5, -0.1, // bottom left
            -0.5, 0.5, -0.1, // top left
        };

        const indices = [6]c_uint{
            // note that we start from 0!
            0, 1, 3, // first triangle
            1, 2, 3, // second triangle
        };

        var VBO: c_uint = undefined;
        var VAO: c_uint = undefined;
        var EBO: c_uint = undefined;

        gl.GenVertexArrays(1, @ptrCast(&VAO));
        errdefer gl.DeleteVertexArrays(1, @ptrCast(&VAO));

        gl.GenBuffers(1, @ptrCast(&VBO));
        errdefer gl.DeleteBuffers(1, @ptrCast(&VBO));

        gl.GenBuffers(1, @ptrCast(&EBO));
        errdefer gl.DeleteBuffers(1, @ptrCast(&EBO));

        gl.BindVertexArray(VAO);
        gl.BindBuffer(gl.ARRAY_BUFFER, VBO);

        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(f32) * vertices.len, &vertices, gl.STATIC_DRAW);

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, 6 * @sizeOf(c_uint), &indices, gl.STATIC_DRAW);

        // Specify and link our vertext attribute description
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        // note that this is allowed, the call to glVertexAttribPointer registered VBO as the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
        gl.BindBuffer(gl.ARRAY_BUFFER, 0);

        // You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO, but this rarely happens. Modifying other
        // VAOs requires a call to glBindVertexArray anyways so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
        gl.BindVertexArray(0);

        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

        // Wireframe mode
        //gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE);

        return Player{
            .render_program = r,
            .vertex_array = VAO,
            .vertex_buffer = VBO,
            .element_buffer = EBO,
        };
    }

    pub fn draw(self: *Player) void {
        self.render_program.use();

        gl.BindVertexArray(self.vertex_array); // seeing as we only have a single VAO there's no need to bind it every time, but we'll do so to keep things a bit more organized
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.element_buffer);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        gl.BindVertexArray(0);
    }

    pub fn keyboardCallback(window: ?*c.GLFWwindow, key: c_int, _: c_int, _: c_int, _: c_int) callconv(.C) void {
        switch (key) {
            c.GLFW_KEY_W, c.GLFW_KEY_UP => {
                player_state.direction = Direction.up;
            },
            c.GLFW_KEY_S, c.GLFW_KEY_DOWN => {
                player_state.direction = Direction.down;
            },
            c.GLFW_KEY_A, c.GLFW_KEY_LEFT => {
                player_state.direction = Direction.left;
            },
            c.GLFW_KEY_D, c.GLFW_KEY_RIGHT => {
                player_state.direction = Direction.right;
            },
            c.GLFW_KEY_ESCAPE => {
                print("ESC pressed, closing window.\n", .{});

                c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
            },
            else => {},
        }
    }
};
