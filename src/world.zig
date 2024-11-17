const spells = @import("spells.zig");
const render = @import("render.zig");
const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;
const enemy = @import("enemy.zig");
const spell_craft = @import("spell_craft.zig");

// Structure for systems: if it requires multiple different entities, place the system in the world, otherwise place it directly in the entity

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

    player_position: Vec2,
    rand: std.Random,
    prng: std.rand.Xoshiro256,
    time_delta_seconds: f32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !World {
        _ = try spell_craft.SpellTree.init(spell_craft.Spells.pumpkin, allocator);
        const pumpkins = try spells.PumpkinSpell.init(allocator);
        const pumpkin_program = try render.RenderProgram.init(render.pumpkin_vertex, render.pumpkin_fragment);
        const pumpkin_effect = try render.RenderableEffect.init(allocator);

        const ghosts = try enemy.Ghost.init(allocator);
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

            .player_position = Vec2{ .x = 0.0, .y = 0.0 },
            .rand = rand,
            .prng = prng,
            .time_delta_seconds = 0.0,

            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.pumpkins.deinit();
        self.pumpkin_program.deinit();
        self.pumpkin_effect.deinit();

        self.ghosts.deinit();
        self.ghost_program.deinit();
        self.ghost_effect.deinit();
    }

    pub fn frame(self: *World) !void {
        const frame_start = std.time.milliTimestamp();
        const last_frame_duration = frame_start - self.last_frame_start;
        self.last_frame_start = frame_start;
        const last_frame_duration_f: f32 = @floatFromInt(last_frame_duration);
        self.time_delta_seconds = last_frame_duration_f / 1000.0;

        self.player_position = Vec2{ .x = 0.0, .y = 0.0 };

        self.pumpkins.spells_system(self.player_position, self.time_delta_seconds);

        try self.ghosts.enemies_system(self.player_position, self.time_delta_seconds);
        self.spell_hit_system();
        self.ghosts.remove_dead_enemies();
        self.pumpkins.remove_spent_spells();

        self.pumpkin_effect.clear();
        for (self.pumpkins.positions.items) |pos| {
            if (pos.len() < 2.0) // culling should take player position into account
                try self.pumpkin_effect.add(pos.x, pos.y);
        }
        self.pumpkin_effect.renderInstanced(&self.pumpkin_program);

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

    fn spell_hit_system(self: *World) void {
        for (self.pumpkins.positions.items, 0..) |spell_position, spell_i| {
            for (self.ghosts.positions.items, 0..) |enemy_position, enemey_yi| {
                if (enemy_position.dist(spell_position) < 0.1) {
                    self.pumpkins.remaining_hits.items[spell_i] -= 1;
                    self.ghosts.healths.items[enemey_yi] -= 1;
                }
            }
        }
    }
};
