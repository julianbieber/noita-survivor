const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;

pub const Ghost = struct {
    positions: std.ArrayList(Vec2),
    healths: std.ArrayList(i32),

    rand: std.Random,
    prng: std.rand.Xoshiro256,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Ghost {
        const positions = std.ArrayList(Vec2).init(allocator);
        const healths = std.ArrayList(i32).init(allocator);

        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();
        return Ghost{
            .positions = positions,
            .healths = healths,
            .rand = rand,
            .prng = prng,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Ghost) void {
        self.positions.deinit();
        self.healths.deinit();
    }
    pub fn enemies_system(self: *Ghost, player_position: Vec2, time_delta_seconds: f32) !void {
        try self.simulate(player_position, time_delta_seconds);
        const p = self.random_position(-1.0, 1.0, -1.0, 1.0);
        try self.positions.append(p);
        try self.healths.append(3);
    }

    pub fn remove_dead_enemies(self: *Ghost) void {
        var i = self.healths.items.len;
        while (i > 0) {
            i -= 1;
            const h = self.healths.items[i];
            if (h <= 0) {
                _ = self.positions.orderedRemove(i);
                _ = self.healths.orderedRemove(i);
            }
        }
    }
    fn simulate(self: *Ghost, player: Vec2, time_delta: f32) !void {
        for (self.positions.items) |*p| {
            const dir = player.sub(p.*).normalize().mul(time_delta);
            p.x += dir.x;
            p.y += dir.y;
        }

        var new_positions = try std.ArrayList(Vec2).initCapacity(self.allocator, self.positions.capacity);
        var new_healths = try std.ArrayList(i32).initCapacity(self.allocator, self.positions.capacity);

        for (self.positions.items, self.healths.items) |p, h| {
            if (p.dist(player) > 0.02) {
                try new_positions.append(p);
                try new_healths.append(h);
            }
        }

        self.positions.deinit();
        self.positions = new_positions;
        self.healths.deinit();
        self.healths = new_healths;
    }

    fn random_position(self: *Ghost, x_min: f32, x_max: f32, y_min: f32, y_max: f32) Vec2 {
        const x = self.rand.float(f32) * (x_max - x_min) + x_min;
        const y = self.rand.float(f32) * (y_max - y_min) + y_min;

        const v = Vec2{ .x = x, .y = y };
        return v;
    }
};
