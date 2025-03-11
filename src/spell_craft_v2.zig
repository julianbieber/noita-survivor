const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const SpellTree = struct {
    children: ArrayList(*SpellTree),
    effect: ?SpellEfect,
    allocator: Allocator,

    /// dimensions depth first left to right, 0 creating a leaf node
    pub fn init(
        dimensions: []const usize,
        allocator: Allocator,
    ) SpellTree {}

    pub fn deinit(self: *const SpellTree) void {}
};

pub const SpellModifier = struct {};

pub const SpellEfect = struct {
    base_damage: f32,
    tag: SpellEffectTags,
};

pub const SpellEffectTags = enum { pumpkin, explosion };
