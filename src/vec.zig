const math = @import("std").math;

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn len(self: Vec2) f32 {
        return math.sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn normalize(self: Vec2) Vec2 {
        const magnitude = @sqrt(self.x * self.x + self.y * self.y);

        return Vec2{
            .x = self.x / magnitude,
            .y = self.y / magnitude,
        };
    }

    pub fn mul(self: Vec2, v: f32) Vec2 {
        return Vec2{ .x = self.x * v, .y = self.y * v };
    }

    pub fn dist(self: Vec2, other: Vec2) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        return @sqrt(dx * dx + dy * dy);
    }
};
