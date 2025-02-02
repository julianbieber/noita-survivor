const render = @import("render.zig");
const std = @import("std");
const math = std.math;
const Vec2 = @import("vec.zig").Vec2;
const SpellEval = @import("spell_craft.zig").SpellEval;

pub const PumpkinSpell = struct {
    positions: std.ArrayList(Vec2),
    directions: std.ArrayList(Vec2),
    remaining_hits: std.ArrayList(i32),
    remaining_duration: std.ArrayList(f32),
    cast_by: std.ArrayList(?*const SpellEval), // Does not own the SpellEval, does not free it on deinint
    current_angle: f32,

    pub fn init(allocator: std.mem.Allocator) !PumpkinSpell {
        const positions = try std.ArrayList(Vec2).initCapacity(allocator, 200);
        const directions = try std.ArrayList(Vec2).initCapacity(allocator, 200);
        const remaining_hits = try std.ArrayList(i32).initCapacity(allocator, 200);
        const remaining_duration = try std.ArrayList(f32).initCapacity(allocator, 200);
        const cast_by = try std.ArrayList(?*const SpellEval).initCapacity(allocator, 200);

        return PumpkinSpell{
            .positions = positions,
            .directions = directions,
            .remaining_hits = remaining_hits,
            .remaining_duration = remaining_duration,
            .cast_by = cast_by,

            .current_angle = 0.0,
        };
    }

    pub fn deinit(self: *PumpkinSpell) void {
        self.positions.deinit();
        self.directions.deinit();
        self.remaining_hits.deinit();
        self.remaining_duration.deinit();
        self.cast_by.deinit();
    }

    pub fn remove_spent_spells(self: *PumpkinSpell, time: f32) void {
        var i = self.remaining_hits.items.len;
        while (i > 0) {
            i -= 1;
            const h = self.remaining_hits.items[i];
            self.remaining_duration.items[i] -= time;
            const r = self.remaining_duration.items[i];
            if (h <= 0 or r < 0.0) {
                _ = self.positions.orderedRemove(i);
                _ = self.directions.orderedRemove(i);
                _ = self.remaining_hits.orderedRemove(i);
                _ = self.remaining_duration.orderedRemove(i);
                _ = self.cast_by.orderedRemove(i);
            }
        }
    }

    pub fn simulate(
        self: *PumpkinSpell,
        time_delta: f32,
    ) void {
        for (self.positions.items, self.directions.items) |*m, d| {
            m.x += d.x * time_delta;
            m.y += d.y * time_delta;
        }
    }

    pub fn add(self: *PumpkinSpell, initial_pos: Vec2, cast_by: ?*const SpellEval) !void {
        const radians = self.current_angle;
        const x = math.cos(radians);
        const y = math.sin(radians);

        try self.positions.append(initial_pos);
        try self.directions.append(Vec2{ .x = y, .y = x });
        try self.remaining_hits.append(2);
        try self.remaining_duration.append(1.0);
        try self.cast_by.append(cast_by);

        self.current_angle += 0.1;
    }
};

pub const ExplosionSpell = struct {
    positions: std.ArrayList(Vec2),
    damage: std.ArrayList(i32),
    max_size: std.ArrayList(f32),
    remaining_duration: std.ArrayList(f32),
    cast_by: std.ArrayList(?*const SpellEval),

    pub fn init(allocator: std.mem.Allocator) ExplosionSpell {
        const positions = std.ArrayList(Vec2).init(allocator);

        const damage = std.ArrayList(i32).init(allocator);
        const max_size = std.ArrayList(f32).init(allocator);
        const remaining_duration = std.ArrayList(f32).init(allocator);
        const cast_by = std.ArrayList(?*const SpellEval).init(allocator);

        return ExplosionSpell{
            .positions = positions,
            .damage = damage,
            .remaining_duration = remaining_duration,
            .max_size = max_size,
            .cast_by = cast_by,
        };
    }

    pub fn deinit(self: *ExplosionSpell) void {
        self.positions.deinit();
        self.damage.deinit();
        self.max_size.deinit();
        self.remaining_duration.deinit();
        self.cast_by.deinit();
    }

    pub fn remove_spent(self: *ExplosionSpell, time_delta: f32) void {
        var i = self.remaining_duration.items.len;
        while (i > 0) {
            i -= 1;
            self.remaining_duration.items[i] -= time_delta;
            const r = self.remaining_duration.items[i];
            if (r <= 0.0) {
                _ = self.positions.orderedRemove(i);
                _ = self.damage.orderedRemove(i);
                _ = self.remaining_duration.orderedRemove(i);
                _ = self.max_size.orderedRemove(i);
                _ = self.cast_by.orderedRemove(i);
            }
        }
    }

    pub fn add(self: *ExplosionSpell, position: Vec2, cast_by: ?*const SpellEval) !void {
        try self.positions.append(position);
        try self.damage.append(10);
        try self.max_size.append(1.0);
        try self.remaining_duration.append(1.0);
        try self.cast_by.append(cast_by);
    }

    // returning damgage, center, radius;
    pub fn get_damage(self: *ExplosionSpell, index: usize) struct { i32, Vec2, f32 } {
        const position = self.positions.items[index];
        const remaining_duration: f32 = self.remaining_duration.items[index];
        const damage: i32 = self.damage.items[index];
        const max_size: f32 = self.max_size.items[index];

        const radius = max_size - max_size / remaining_duration; // remove_spent prevents div by 0; the formula should match the speread in the related fragment shader

        return .{ damage, position, radius };
    }
};
