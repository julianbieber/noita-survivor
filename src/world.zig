const spells = @import("spells.zig");
const render = @import("render.zig");
const std = @import("std");

pub const World = struct {
    pumpkins: spells.PumpkinSpell,
    pumpkin_program: render.RenderProgram,
    pumpkin_effect: render.RenderableEffect,
    last_frame_duration: f32,

    pub fn init(allocator: std.mem.Allocator) !World {
        const pumpkins = try spells.PumpkinSpell.init(allocator);
        const pumpkin_program = try render.RenderProgram.init(render.pumpkin_vertex, render.pumpkin_fragment);
        const pumpkin_effect = try render.RenderableEffect.init(allocator);

        return World{
            .pumpkins = pumpkins,
            .pumpkin_program = pumpkin_program,
            .pumpkin_effect = pumpkin_effect,
            .last_frame_duration = 0.0,
        };
    }

    pub fn deinit(self: *World) void {
        self.pumpkins.deinit();
        self.pumpkin_program.deinit();
        self.pumpkin_effect.deinit();
    }

    pub fn frame(self: *World) !void {
        const frame_start = std.time.nanoTimestamp();
        self.pumpkins.simulate(self.last_frame_duration);
        self.pumpkins.add(spells.Vec2{ .x = 0.0, .y = 0.0 });

        self.pumpkin_effect.clear();

        for (self.pumpkins.positions.items) |pos| {
            if (pos.pos.len() < 2.0)
                try self.pumpkin_effect.add(pos.pos.x, pos.pos.y);
        }

        self.pumpkin_effect.renderInstanced(&self.pumpkin_program);

        const frame_end = std.time.nanoTimestamp();
        const delta_f: f32 = @floatFromInt(frame_end - frame_start);
        self.last_frame_duration = delta_f / 1000000.0;
    }
};
