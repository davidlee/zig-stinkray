const std = @import("std");
const input = @import("input.zig");
const main = @import("main.zig");

pub fn tick(alloc: std.mem.Allocator, world: *main.World) void {
    _ = alloc;
    input.handleKeyboard(world);
    input.handleMouse(world);
}
pub fn deinit() void {}
