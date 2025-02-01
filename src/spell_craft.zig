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

    pub fn to_eval(self: *const SpellTree) !std.ArrayList(SpellEval) { // TODO not sure how to represent the result of the spell tree (mayebe array with one entry per leaf?)
        const initial = SpellEval{ .cast_time = 0.0, .remaining = 0.0, .projectiles = 0 };

        var r = std.ArrayList(SpellEval).init(self.allocator);
        try self.to_eval_rec(initial, &r);
        return r;
    }

    fn to_eval_rec(self: *const SpellTree, current: SpellEval, finished: *std.ArrayList(SpellEval)) !void {
        const this_level = current.add_spell(self.spell);
        if (self.children.items.len == 0) {
            try finished.append(this_level);
        } else {
            for (self.children.items) |child| {
                try child.to_eval_rec(this_level, finished);
            }
        }
    }
};

pub const SpellTags = enum { multi_cast, pumpkin };

fn meta_for_spell(spell: Spells) SpellMeta {
    switch (spell) {
        .multi_cast => |n| {
            const n_f: f32 = @floatFromInt(n);
            return SpellMeta{ .max_children = 1, .cast_time = 0.01 * n_f }; // maybe add a fucntion that lowers the impact of further casts on the cast time formula
        },
        .pumpkin => |_| {
            return SpellMeta{ .max_children = 0, .cast_time = 0.3 };
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
    projectiles: u32,

    fn add_spell(self: SpellEval, spell: Spells) SpellEval {
        const meta = meta_for_spell(spell);
        switch (spell) {
            .multi_cast => |n| {
                var count: u32 = 0;
                if (self.projectiles == 0) {
                    count = n;
                } else {
                    count = self.projectiles * n;
                }
                return SpellEval{ .cast_time = self.cast_time + meta.cast_time, .remaining = self.remaining, .projectiles = count }; // maybe add a fucntion that lowers the impact of further casts on the cast time formula
            },
            .pumpkin => |_| {
                return SpellEval{ .cast_time = self.cast_time + meta.cast_time, .remaining = self.remaining, .projectiles = self.projectiles + 1 };
            },
        }
    }

    pub fn advance_time(self: *SpellEval, delta_time: f32) bool {
        self.remaining -= delta_time;
        if (self.remaining < 0.0) {
            self.remaining = self.cast_time; // Does not handel multiple casts in a single frame
            return true;
        } else {
            return false;
        }
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

test "evaluate tree" {
    const allocator = testing.allocator;

    var tree = try SpellTree.init(Spells{ .multi_cast = 1 }, allocator);
    defer tree.deinit();
    for (0..4) |_| {
        _ = try tree.add(Spells{ .multi_cast = 1 });
    }
    _ = try tree.add(Spells.pumpkin);
    const eval = try tree.to_eval();
    defer eval.deinit();

    try testing.expect(eval.items.len == 1);
}
