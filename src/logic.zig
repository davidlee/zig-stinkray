const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

const input = @import("input.zig");
const vec = @import("vec.zig");

const t = @import("terrain.zig");
const player = @import("player.zig");

pub fn tick(alloc: std.mem.Allocator) void {
    _ = alloc;
    input.handleKeyboard();
    input.handleMouse();
    // player.move() catch {};
    // _ = 4;
}
pub fn deinit() void {}

// public data
