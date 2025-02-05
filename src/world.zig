const spells = @import("spells.zig");
const render = @import("render.zig");
const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;
const enemy = @import("enemy.zig");
const spell_craft = @import("spell_craft.zig");
const SpellEval = spell_craft.SpellEval;

// Structure for systems: if it requires multiple different entities, place the system in the world, otherwise place it directly in the entity

pub const World = struct {
    pumpkins: spells.PumpkinSpell,
    pumpkin_program: render.RenderProgram,
    pumpkin_effect: render.RenderableEffect,

    ghosts: enemy.Ghost,
    ghost_program: render.RenderProgram,
    ghost_effect: render.RenderableEffect,

    explosions: spells.ExplosionSpell,
    explosion_program: render.RenderProgram,
    explosion_effect: render.RenderableEffect,

    last_frame_start: i64,
    frames_since_second: i32,
    duration_since_second: i64,

    player_position: Vec2,
    player_spell_tree: spell_craft.SpellTree,
    player_current_spell: std.ArrayList(spell_craft.SpellEval),

    rand: std.Random,
    prng: std.rand.Xoshiro256,
    time_delta_seconds: f32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !World {
        const pumpkins = try spells.PumpkinSpell.init(allocator);
        const pumpkin_program = try render.RenderProgram.init(render.pumpkin_vertex, render.pumpkin_fragment);
        const pumpkin_buffer_descriptr = render.BufferDescriptor{ .size_per_element = 2, .stride = @sizeOf(f32) * 2 };
        const pumpkin_effect = try render.RenderableEffect.init(allocator, &[_]render.BufferDescriptor{pumpkin_buffer_descriptr});

        const ghosts = try enemy.Ghost.init(allocator);
        const ghost_program = try render.RenderProgram.init(render.ghost_vertex, render.ghost_fragment);
        const ghost_buffer_descriptor = render.BufferDescriptor{ .size_per_element = 2, .stride = @sizeOf(f32) * 2 };
        const ghost_effect = try render.RenderableEffect.init(allocator, &[_]render.BufferDescriptor{ghost_buffer_descriptor});

        const explosions = spells.ExplosionSpell.init(allocator);
        const explosions_program = try render.RenderProgram.init(render.explosion_vertex, render.explosion_fragment);
        const explosion_buffer_descriptors = [_]render.BufferDescriptor{
            render.BufferDescriptor{ .size_per_element = 2, .stride = @sizeOf(f32) * 2 }, // positions
            render.BufferDescriptor{ .size_per_element = 1, .stride = @sizeOf(f32) }, // max_size
            render.BufferDescriptor{ .size_per_element = 1, .stride = @sizeOf(f32) }, // remaining_duration
        };
        const explosions_effect = try render.RenderableEffect.init_cube(allocator, &explosion_buffer_descriptors);

        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();

        var tree = try spell_craft.SpellTree.init(spell_craft.Spells{ .multi_cast = 5 }, allocator);
        for (0..4) |_| {
            const added = try tree.add(spell_craft.Spells{ .multi_cast = 2 });
            if (!added) {
                return error.FailedToAddSpell;
            }
        }
        const on_hit_tree = try spell_craft.SpellTree.init(spell_craft.Spells.explosion, allocator);
        {
            const added = try tree.add(spell_craft.Spells{ .on_hit = try on_hit_tree.to_heap() });
            if (!added) {
                return error.FailedToAddSpell;
            }
        }
        const added = try tree.add(spell_craft.Spells.pumpkin);
        if (!added) {
            return error.FailedToAddSpell;
        }
        const current_spell = try tree.to_eval();

        return World{
            .pumpkins = pumpkins,
            .pumpkin_program = pumpkin_program,
            .pumpkin_effect = pumpkin_effect,

            .ghosts = ghosts,
            .ghost_program = ghost_program,
            .ghost_effect = ghost_effect,

            .explosions = explosions,
            .explosion_program = explosions_program,
            .explosion_effect = explosions_effect,

            .last_frame_start = std.time.milliTimestamp(),
            .frames_since_second = 0,
            .duration_since_second = 0,

            .player_position = Vec2{ .x = 0.0, .y = 0.0 },
            .rand = rand,
            .prng = prng,
            .time_delta_seconds = 0.0,

            .player_spell_tree = tree,
            .player_current_spell = current_spell,

            .allocator = allocator,
        };
    }

    pub fn deinit(self: *World) void {
        self.pumpkins.deinit();
        self.pumpkin_program.deinit();
        self.pumpkin_effect.deinit();

        self.explosions.deinit();
        self.explosion_program.deinit();
        self.explosion_effect.deinit();

        self.ghosts.deinit();
        self.ghost_program.deinit();
        self.ghost_effect.deinit();

        self.player_spell_tree.deinit();
        for (self.player_current_spell.items) |s| {
            s.deinit();
        }
        self.player_current_spell.deinit();
    }

    pub fn frame(self: *World) !void {
        const frame_start = std.time.milliTimestamp();
        const last_frame_duration = frame_start - self.last_frame_start;
        self.last_frame_start = frame_start;
        const last_frame_duration_f: f32 = @floatFromInt(last_frame_duration);
        self.time_delta_seconds = last_frame_duration_f / 1000.0;

        self.player_position = Vec2{ .x = 0.0, .y = 0.0 };

        try self.eval_spells_system();
        self.pumpkins.simulate(self.time_delta_seconds);

        try self.ghosts.enemies_system(self.player_position, self.time_delta_seconds);
        try self.spell_hit_system();
        self.ghosts.remove_dead_enemies();
        self.pumpkins.remove_spent_spells(self.time_delta_seconds);

        self.explosions.remove_spent(self.time_delta_seconds);

        try self.render_pumpkins();

        try self.render_ghosts();

        try self.render_explosions();

        self.fps_system(last_frame_duration);
    }

    fn random_position(self: *World, x_min: f32, x_max: f32, y_min: f32, y_max: f32) Vec2 {
        const x = self.rand.float(f32) * (x_max - x_min) + x_min;
        const y = self.rand.float(f32) * (y_max - y_min) + y_min;

        const v = Vec2{ .x = x, .y = y };
        return v;
    }

    fn render_ghosts(self: *World) !void {
        self.ghost_effect.clear();
        for (self.ghosts.positions.items) |pos| {
            // if (pos.len() < 2.0)
            try self.ghost_effect.add(0, &[_]f32{ pos.x, pos.y });
        }
        self.ghost_effect.render_instanced(&self.ghost_program, 3);
    }

    fn render_explosions(self: *World) !void {
        self.explosion_effect.clear();
        for (self.explosions.positions.items, self.explosions.max_size.items, self.explosions.remaining_duration.items) |pos, size, dur| {
            // if (pos.len() < 2.0)
            try self.explosion_effect.add(0, &[_]f32{ pos.x, pos.y });
            try self.explosion_effect.add(1, &[_]f32{size});
            try self.explosion_effect.add(2, &[_]f32{dur});
        }
        self.explosion_effect.render_instanced(&self.explosion_program, 6);
    }

    fn render_pumpkins(self: *World) !void {
        self.pumpkin_effect.clear();
        for (self.pumpkins.positions.items) |pos| {
            if (pos.len() < 2.0) // culling should take player position into account
                try self.pumpkin_effect.add(0, &[_]f32{ pos.x, pos.y });
        }
        self.pumpkin_effect.render_instanced(&self.pumpkin_program, 3);
    }

    fn eval_spells_system(self: *World) !void {
        for (self.player_current_spell.items) |*spell| {
            const cast = spell.advance_time(self.time_delta_seconds);
            if (cast) {
                try apply_single_spell_eval(self, spell, self.player_position);
            }
        }
    }

    fn apply_single_spell_eval(self: *World, spell: *const SpellEval, at: Vec2) !void {
        // std.debug.print("{d}projectiles\n", .{spell.repetitions});
        for (0..spell.repetitions) |_| {
            switch (spell.own_type) {
                .multi_cast => {},
                .pumpkin => {
                    try self.pumpkins.add(at, spell);
                },
                .on_hit => {},
                .explosion => {
                    try self.explosions.add(at, spell);
                },
            }
        }
    }
    fn fps_system(self: *World, last_frame_duration: i64) void {
        self.duration_since_second += last_frame_duration;
        if (self.duration_since_second >= 1000) {
            std.debug.print("{d}FPS\n", .{self.frames_since_second});
            self.frames_since_second = 0;
            self.duration_since_second = 0;
        } else {
            self.frames_since_second += 1;
        }
    }

    fn spell_hit_system(self: *World) !void {
        for (self.pumpkins.positions.items, 0..) |spell_position, spell_i| {
            for (self.ghosts.positions.items, 0..) |enemy_position, enemey_yi| {
                if (enemy_position.dist(spell_position) < 0.1) {
                    self.pumpkins.remaining_hits.items[spell_i] -= 1;
                    self.ghosts.healths.items[enemey_yi] -= 1;
                    if (self.pumpkins.cast_by.items[spell_i]) |c| {
                        for (c.on_hit_spell.items) |on_hit| {
                            try self.apply_single_spell_eval(&on_hit, spell_position);
                        }
                    }
                }
            }
        }

        for (0..self.explosions.positions.items.len) |explosion_index| {
            const explosion_effect = self.explosions.get_damage(explosion_index);

            for (self.ghosts.positions.items, 0..) |enemy_position, enemy_i| {
                if (enemy_position.dist(explosion_effect[1]) < explosion_effect[2]) {
                    self.ghosts.healths.items[enemy_i] -= explosion_effect[0];
                    if (self.explosions.cast_by.items[explosion_index]) |c| {
                        for (c.on_hit_spell.items) |on_hit| {
                            try self.apply_single_spell_eval(&on_hit, explosion_effect[1]);
                        }
                    }
                }
            }
        }
    }
};
