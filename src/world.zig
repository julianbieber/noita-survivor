const spells = @import("spells.zig");
const render = @import("render.zig");
const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;
const enemy = @import("enemy.zig");

pub const World = struct {
    pumpkins: spells.PumpkinSpell,
    pumpkin_program: render.RenderProgram,
    pumpkin_effect: render.RenderableEffect,

    ghosts: enemy.Ghost,
    ghost_program: render.RenderProgram,
    ghost_effect: render.RenderableEffect,

    last_frame_start: i64,
    frames_since_second: i32,
    duration_since_second: i64,

    rand: std.Random,

    pub fn init(allocator: std.mem.Allocator) !World {
        const pumpkins = try spells.PumpkinSpell.init(allocator);
        const pumpkin_program = try render.RenderProgram.init(render.pumpkin_vertex, render.pumpkin_fragment);
        const pumpkin_effect = try render.RenderableEffect.init(allocator);

        const ghosts = enemy.Ghost.init(allocator);
        const ghost_program = try render.RenderProgram.init(render.ghost_vertex, render.ghost_fragment);
        const ghost_effect = try render.RenderableEffect.init(allocator);

        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();

        return World{
            .pumpkins = pumpkins,
            .pumpkin_program = pumpkin_program,
            .pumpkin_effect = pumpkin_effect,

            .ghosts = ghosts,
            .ghost_program = ghost_program,
            .ghost_effect = ghost_effect,

            .last_frame_start = std.time.milliTimestamp(),
            .frames_since_second = 0,
            .duration_since_second = 0,

            .rand = rand,
        };
    }

    pub fn deinit(self: *World) void {
        self.pumpkins.deinit();
        self.pumpkin_program.deinit();
        self.pumpkin_effect.deinit();
    }

    pub fn frame(self: *World) !void {
        const frame_start = std.time.milliTimestamp();
        const last_frame_duration = frame_start - self.last_frame_start;
        self.last_frame_start = frame_start;
        const last_frame_duration_f: f32 = @floatFromInt(last_frame_duration);
        const time_delta_seconds = last_frame_duration_f / 1000.0;

        self.pumpkins.simulate(time_delta_seconds);
        self.pumpkins.add(Vec2{ .x = 0.0, .y = 0.0 }); // later something else will trigger the spawn

        self.pumpkin_effect.clear();
        for (self.pumpkins.positions.items) |pos| {
            if (pos.pos.len() < 2.0) // culling should take player position into account
                try self.pumpkin_effect.add(pos.pos.x, pos.pos.y);
        }
        self.pumpkin_effect.renderInstanced(&self.pumpkin_program);

        try self.ghosts.simulate(Vec2{ .x = 0.0, .y = 0.0 }, time_delta_seconds);
        try self.spawn_random_ghost(-1.0, 1.0, -1.0, 1.0);

        self.ghost_effect.clear();
        for (self.ghosts.positions.items) |pos| {
            // if (pos.len() < 2.0)
            try self.ghost_effect.add(pos.x, pos.y);
        }
        self.ghost_effect.renderInstanced(&self.ghost_program);

        self.duration_since_second += last_frame_duration;
        if (self.duration_since_second >= 1000) {
            std.debug.print("{d}FPS\n", .{self.frames_since_second});
            self.frames_since_second = 0;
            self.duration_since_second = 0;
        } else {
            self.frames_since_second += 1;
        }
    }

    fn spawn_random_ghost(self: *World, x_min: f32, x_max: f32, y_min: f32, y_max: f32) !void {
        const x = self.rand.float(f32) * (x_max - x_min) + x_min;
        const y = self.rand.float(f32) * (y_max - y_min) + y_min;

        const v = Vec2{ .x = x, .y = y };

        try self.ghosts.positions.append(v);
    }
};
