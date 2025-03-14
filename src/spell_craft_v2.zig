const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const SpellTree = struct {
    children: ArrayList(*SpellTree),
    modifier: SpellModifier,
    effect: ?SpellEfect,
    allocator: Allocator,

    /// dimensions: number of children per depth
    pub fn init(
        dimensions: []const usize,
        allocator: Allocator,
    ) !SpellTree {
        if (dimensions.len == 0) {
            const children = ArrayList(*SpellTree).init(allocator);
            return SpellTree{
                .children = children,
                .effect = null,
                .modifier = Unmodified,
                .allocator = Allocator,
            };
        } else {
            const children_len = dimensions[0];
            const inner_dimension = dimensions[1..];
            var children = try ArrayList(*SpellTree).initCapacity(allocator, children_len);
            for (0..children_len) |_| {
                const child = try SpellTree.init(inner_dimension, allocator);
                const p = try allocator.create(SpellTree);
                p.* = child;

                try children.append(p);
            }
        }
    }

    pub fn set_modifier(self: *SpellTree, path: []const usize, modifier: SpellModifier) !void {
        var target = try self.traverse(path);
        target.modifier = modifier;
    }

    pub fn set_effect(self: *SpellTree, path: []const usize, effect: SpellEfect) !void {
        var target = try self.traverse(path);
        target.effect = effect;
    }

    fn traverse(self: *const SpellTree, path: []const usize) !*SpellTree {
        if (path.len == 0) return self;
        if (path.len == 1) {
            const i = path[0];
            if (i >= self.children.items.len) {
                return error.PathDoesNotExist;
            }
            return self.children.items[i];
        } else {
            const i = path[0];
            const tail = path[1..];
            if (i >= self.children.items.len) {
                return error.PathDoesNotExist;
            }
            const child = self.children.items[i];
            return child.traverse(tail);
        }
    }

    pub fn deinit(self: *const SpellTree) void {
        for (self.children.items) |value| {
            self.allocator.destroy(value);
        }
        self.children.deinit();
    }
};

pub const SpellModifier = struct {
    damage_multiplier: f32,
    projectile_add: i32,
    cast_time_multiplier: f32,
};

const Unmodified = SpellModifier{ .cast_time_multiplier = 1.0, .damage_multiplier = 1.0, .projectile_add = 0 };

pub const SpellEfect = struct {
    base_damage: f32,
    cast_time: f32,
    count: i32,
    tag: SpellEffectTags,
};

pub const SpellEffectTags = enum { pumpkin, explosion };

const testing = std.testing;
test "initialize a single layer spell tree" {
    const allocator = testing.allocator;

    var tree = try SpellTree.init([]usize, allocator);
    try tree.set_effect([_]usize{0}, SpellEfect{ .base_damage = 1, .tag = SpellEffectTags });

    testing.expectEqual(123, tree.effect.?.base_damagetree.effect.?.base_damage);
}
