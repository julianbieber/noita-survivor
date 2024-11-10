const std = @import("std");
const Vec2 = @import("vec.zig").Vec2;

pub const Ghost = struct {
    positions: std.ArrayList(Vec2),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Ghost {
        const positions = std.ArrayList(Vec2).init(allocator);
        return Ghost{ .positions = positions, .allocator = allocator };
    }

    pub fn deinit(self: *Ghost) void {
        self.positions.deinit();
    }

    pub fn simulate(self: *Ghost, player: Vec2, time_delta: f32) !void {
        for (self.positions.items) |*p| {
            const dir = player.sub(p.*).normalize().mul(time_delta);
            p.x += dir.x;
            p.y += dir.y;
        }

        var new_positions = try std.ArrayList(Vec2).initCapacity(self.allocator, self.positions.capacity);

        for (self.positions.items) |p| {
            if (p.dist(player) > 0.02) {
                try new_positions.append(p);
            }
        }

        self.positions.deinit();
        self.positions = new_positions;
    }
};
