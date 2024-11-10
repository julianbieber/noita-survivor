const render = @import("render.zig");
const std = @import("std");
const math = std.math;
const Vec2 = @import("vec.zig").Vec2;

pub const PumpkinSpell = struct {
    positions: std.ArrayList(Vec2),
    directions: std.ArrayList(Vec2),
    remaining_hits: std.ArrayList(i32),
    current_angle: f32,
    oldest_index: usize,

    pub fn init(allocator: std.mem.Allocator) !PumpkinSpell {
        const positions = try std.ArrayList(Vec2).initCapacity(allocator, 200);
        const directions = try std.ArrayList(Vec2).initCapacity(allocator, 200);
        const remaining_hits = try std.ArrayList(i32).initCapacity(allocator, 200);

        return PumpkinSpell{
            .positions = positions,
            .directions = directions,
            .remaining_hits = remaining_hits,

            .current_angle = 0.0,
            .oldest_index = 0,
        };
    }

    pub fn deinit(self: *PumpkinSpell) void {
        self.positions.deinit();
        self.directions.deinit();
        self.remaining_hits.deinit();
    }

    pub fn spells_system(self: *PumpkinSpell, player_position: Vec2, time_delta_seconds: f32) void {
        self.simulate(time_delta_seconds);
        self.add(player_position); // later something else will trigger the spawn
    }

    pub fn remove_spent_spells(self: *PumpkinSpell) void {
        var i = self.remaining_hits.items.len;
        while (i > 0) {
            i -= 1;
            const h = self.remaining_hits.items[i];
            if (h <= 0) {
                _ = self.positions.orderedRemove(i);
                _ = self.directions.orderedRemove(i);
                _ = self.remaining_hits.orderedRemove(i);
            }
        }
    }

    fn simulate(
        self: *PumpkinSpell,
        time_delta: f32,
    ) void {
        for (self.positions.items, self.directions.items) |*m, d| {
            m.x += d.x * time_delta;
            m.y += d.y * time_delta;
        }
    }

    fn add(self: *PumpkinSpell, initial_pos: Vec2) void {
        const radians = self.current_angle;
        const x = math.cos(radians);
        const y = math.sin(radians);

        if (self.positions.items.len < self.positions.capacity) {
            self.positions.appendAssumeCapacity(initial_pos);
            self.directions.appendAssumeCapacity(Vec2{ .x = y, .y = x });
            self.remaining_hits.appendAssumeCapacity(2);
        } else {
            self.positions.items[self.oldest_index] = initial_pos;
            self.directions.items[self.oldest_index] = Vec2{ .x = y, .y = x };
            self.remaining_hits.items[self.oldest_index] = 2;
            self.oldest_index += 1;
            self.oldest_index = self.oldest_index % self.positions.capacity;
        }
        self.current_angle += 0.1;
    }
};
