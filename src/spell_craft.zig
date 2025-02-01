//! The idea behind the spell crafting/casting implementation is to have one representation of the spell tree adequat for editing and displaying.
//! A second representation suitable for the scheduled casting of the spells on a timer.
//! We aim to reduce the amount of allocations inside of the casting implementation since it will be executed regularily.

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
    pub fn to_heap(self: SpellTree) !*SpellTree {
        const u = try self.allocator.create(SpellTree);
        u.* = self;
        return u;
    }

    pub fn deinit(self: *SpellTree) void {
        switch (self.spell) {
            .on_hit => |inner| {
                inner.deinit();
                self.allocator.destroy(inner);
            },
            else => {},
        }
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

    // Each leaf node results in an indivivual eval
    pub fn to_eval(self: *const SpellTree) !std.ArrayList(SpellEval) {
        var initial = SpellEval{
            .cast_time = 0.0,
            .remaining = 0.0,
            .repetitions = 0,
            .own_type = SpellTags.multi_cast, // using an invalid start to detect errors fter building all evals
            .on_hit_spell = std.ArrayList(SpellEval).init(self.allocator),
            .allocator = self.allocator,
        };

        var r = std.ArrayList(SpellEval).init(self.allocator);
        try self.to_eval_rec(&initial, &r);
        return r;
    }

    fn to_eval_rec(self: *const SpellTree, current: *SpellEval, finished: *std.ArrayList(SpellEval)) std.mem.Allocator.Error!void {
        var this_level = try current.add_spell(self.spell);
        if (self.children.items.len == 0) {
            try finished.append(this_level);
        } else {
            for (self.children.items) |child| {
                try child.to_eval_rec(&this_level, finished);
            }
        }
    }
};

pub const SpellTags = enum { multi_cast, pumpkin, on_hit, explosion };

fn meta_for_spell(spell: Spells) SpellMeta {
    switch (spell) {
        .multi_cast => |n| {
            const n_f: f32 = @floatFromInt(n);
            return SpellMeta{ .max_children = 1, .cast_time = 0.01 * n_f }; // maybe add a fucntion that lowers the impact of further casts on the cast time formula
        },
        .pumpkin => |_| {
            return SpellMeta{ .max_children = 0, .cast_time = 0.3 };
        },
        .on_hit => |_| {
            return SpellMeta{ .max_children = 1, .cast_time = 0.1 }; // max_children must be 1, otherwise SpellEval needs adjustment
        },
        .explosion => |_| {
            return SpellMeta{ .max_children = 0, .cast_time = 0.3 };
        },
    }
}

const SpellMeta = struct {
    max_children: u8,
    cast_time: f32,
};

pub const Spells = union(SpellTags) { multi_cast: u8, pumpkin: void, on_hit: *SpellTree, explosion: void };

pub const SpellEval = struct {
    cast_time: f32, // cast time to add after cast happened
    remaining: f32, // keeps track of the time to next cast
    repetitions: u32,
    own_type: SpellTags, // must be only one of the terminal spells
    on_hit_spell: std.ArrayList(SpellEval),
    allocator: std.mem.Allocator, // used to destroy the on hit pointer

    fn add_spell(self: *SpellEval, spell: Spells) !SpellEval {
        const meta = meta_for_spell(spell);
        switch (spell) {
            .multi_cast => |n| {
                var count: u32 = 0;
                if (self.repetitions == 0) {
                    count = n;
                } else {
                    count = self.repetitions * n;
                }
                return SpellEval{
                    .cast_time = self.cast_time + meta.cast_time,
                    .remaining = self.remaining,
                    .repetitions = count,
                    .on_hit_spell = self.on_hit_spell,
                    .own_type = SpellTags.multi_cast, // Should be overwriten by the end of building the eval
                    .allocator = self.allocator,
                }; // maybe add a function that lowers the impact of further casts on the cast time formula
            },
            .pumpkin => |_| {
                return SpellEval{
                    .cast_time = self.cast_time + meta.cast_time,
                    .remaining = self.remaining,
                    .repetitions = self.repetitions + 1,
                    .on_hit_spell = self.on_hit_spell,
                    .own_type = SpellTags.pumpkin,
                    .allocator = self.allocator,
                };
            },
            .on_hit => |inner| {
                const inner_eval = try inner.to_eval();
                defer inner_eval.deinit();
                try self.on_hit_spell.appendSlice(inner_eval.items);
                return SpellEval{
                    .cast_time = self.cast_time + meta.cast_time,
                    .remaining = self.remaining,
                    .repetitions = self.repetitions,
                    .on_hit_spell = self.on_hit_spell,
                    .own_type = SpellTags.on_hit,
                    .allocator = self.allocator,
                };
            },
            .explosion => |_| {
                return SpellEval{
                    .cast_time = self.cast_time + meta.cast_time,
                    .remaining = self.remaining,
                    .repetitions = self.repetitions + 1,
                    .on_hit_spell = self.on_hit_spell,
                    .own_type = SpellTags.explosion,
                    .allocator = self.allocator,
                };
            },
        }
    }

    pub fn deinit(self: *const SpellEval) void {
        for (self.on_hit_spell.items) |*i| {
            i.deinit();
        }
        self.on_hit_spell.deinit();
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

test "eval on hit effects" {
    const allocator = testing.allocator;

    var tree = try SpellTree.init(Spells{ .multi_cast = 1 }, allocator);
    defer tree.deinit();
    for (0..4) |_| {
        _ = try tree.add(Spells{ .multi_cast = 1 });
    }

    const on_hit_tree = try SpellTree.init(Spells.pumpkin, allocator);
    _ = try tree.add(Spells{ .on_hit = try on_hit_tree.to_heap() });
    _ = try tree.add(Spells.pumpkin);
    const eval = try tree.to_eval();
    for (eval.items) |e| {
        defer e.deinit();
    }
    defer eval.deinit();

    try testing.expect(eval.items.len == 1);
}
