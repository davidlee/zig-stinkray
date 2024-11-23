const std = @import("std");
const rl = @import("raylib");

const logic = @import("logic.zig");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");
const vec = @import("vec.zig");
const m = @import("main.zig");

pub fn handleKeyboard(world: *m.World) void {
    inline for (MovementKeys) |x| {
        if (rl.isKeyDown(x[0])) {
            world.player.moveTo(world, x[1]) catch {};
        }
    }
}

const MovementKeys = .{
    .{ rl.KeyboardKey.key_up, .North },
    .{ rl.KeyboardKey.key_down, .South },
    .{ rl.KeyboardKey.key_left, .West },
    .{ rl.KeyboardKey.key_right, .East },
};

pub fn handleMouse(world: *m.World) void {
    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        const px = vec.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };

        const uvec = graphics.pxToCell(px);
        var cell = world.cells.getCellAtZYX(0, uvec.y, uvec.x);

        const tile = switch (cell.tile) {
            .Empty => terrain.Tile{ .Solid = .Stone },
            .Floor => terrain.Tile{ .Solid = .Stone },
            .Solid => terrain.Tile{ .Floor = .Dirt },
        };

        cell.tile = tile;
    }
}
