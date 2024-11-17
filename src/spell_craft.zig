const std = @import("std");

pub const SpellTree = struct {
    spell: Spells,
    children: std.ArrayList(*SpellTree),
    allocator: std.mem.Allocator,

    pub fn init(spell: Spells, allocator: std.mem.Allocator) !SpellTree {
        const children = std.ArrayList(*SpellTree).init(allocator);

        return SpellTree{
            .spell = spell,
            .children = children,
            .allocator = allocator,
        };
    }
    fn to_heap(self: SpellTree) !*SpellTree {
        const u = try self.allocator.create(SpellTree);
        u.* = self;
        return u;
    }

    pub fn deinit(self: *SpellTree) void {
        for (self.children.items) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.children.deinit();
    }

    pub fn add(self: *SpellTree, spell: Spells) !bool {
        const meta = meta_for_spell(self.spell);
        const max_children = meta.max_children;
        if (self.children.items.len < max_children) {
            const n = try SpellTree.init(spell, self.allocator);
            const p = try n.to_heap();
            try self.children.append(p);
            return true;
        } else {
            for (self.children.items) |c| {
                const added = try c.add(spell);
                if (added) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn to_eval(self: *const SpellTree) !SpellEval {
        var total_time: f32 = 0.0;
        var casts = std.ArrayList(Projectiles).init();
    }

    fn to_eval_rec(self: *const SpellTree, casts: *std.ArrayList(Projectiles), total_time: *f32) !void {
        const meta = meta_for_spell(self.spell);
        total_time.* += meta.cast_time;
        switch (self.spell) {
            .multi_cast => |c| {
                return;
            },
        }
    }
};

pub const SpellTags = enum { multi_cast, pumpkin };
pub const ProjectileTags = enum { pumpkin };
pub const Projectiles = union(ProjectileTags) { pumpkin: u32 };

fn meta_for_spell(spell: Spells) SpellMeta {
    switch (spell) {
        .multi_cast => |n| {
            const n_f: f32 = @floatFromInt(n);
            return SpellMeta{ .max_children = 1, .cast_time = 0.1 * n_f }; // maybe add a fucntion that lowers the impact of further casts on the cast time formula
        },
        .pumpkin => |_| {
            return SpellMeta{ .max_children = 0, .cast_time = 0.5 };
        },
    }
}

const SpellMeta = struct {
    max_children: u8,
    cast_time: f32,
};

pub const Spells = union(SpellTags) { multi_cast: u8, pumpkin: void };

pub const SpellEval = struct {
    cast_time: f32,
    remaining: f32,
    casts: std.ArrayList(Projectiles),

    fn add_projectile(self: *SpellEval, p: Projectiles) !void {
        for (self.casts.items) |*c| {
            if (c.*.pumpkin)
        }
    }

    pub fn deinit(self: *SpellEval) void {
        self.casts.deinit();
    }
};

const testing = std.testing;

test "instantiate and free" {
    _ = Spells{ .multi_cast = 5 };
    _ = Spells.pumpkin;
    const allocator = testing.allocator;

    var tree = try SpellTree.init(Spells{ .multi_cast = 1 }, allocator);
    defer tree.deinit();
    for (0..4) |_| {
        const added = try tree.add(Spells{ .multi_cast = 1 });
        try testing.expect(added);
    }

    {
        const added = try tree.add(Spells.pumpkin);
        try testing.expect(added);
    }
    {
        const added = try tree.add(Spells.pumpkin);
        try testing.expect(!added);
    }
}
