const render = @import("render.zig");
const std = @import("std");
const math = std.math;
const Vec2 = @import("vec.zig").Vec2;

const SpellMovement = struct {
    pos: Vec2,
    dir: Vec2,
};

pub const PumpkinSpell = struct {
    positions: std.ArrayList(SpellMovement),
    current_angle: f32,
    oldest_index: usize,

    pub fn init(allocator: std.mem.Allocator) !PumpkinSpell {
        const positions = try std.ArrayList(SpellMovement).initCapacity(allocator, 200);

        return PumpkinSpell{
            .positions = positions,
            .current_angle = 0.0,
            .oldest_index = 0,
        };
    }

    pub fn deinit(self: *PumpkinSpell) void {
        self.positions.deinit();
    }

    pub fn simulate(
        self: *PumpkinSpell,
        time_delta: f32,
    ) void {
        for (self.positions.items) |*m| {
            m.pos.x += m.dir.x * time_delta;
            m.pos.y += m.dir.y * time_delta;
        }
    }

    pub fn add(self: *PumpkinSpell, initial_pos: Vec2) void {
        const radians = self.current_angle;
        const x = math.cos(radians);
        const y = math.sin(radians);

        if (self.positions.items.len < self.positions.capacity) {
            self.positions.appendAssumeCapacity(SpellMovement{ .pos = initial_pos, .dir = Vec2{ .x = y, .y = x } });
        } else {
            self.positions.items[self.oldest_index] =
                SpellMovement{ .pos = initial_pos, .dir = Vec2{ .x = y, .y = x } };
            self.oldest_index += 1;
            self.oldest_index = self.oldest_index % self.positions.capacity;
        }
        self.current_angle += 0.01;
    }
};
