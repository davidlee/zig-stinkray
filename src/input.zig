const std = @import("std");
const rl = @import("raylib");

const logic = @import("logic.zig");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");
const vec = @import("vec.zig");

pub fn handleKeyboard() void {
    inline for (MovementKeys) |x| {
        if (rl.isKeyDown(x[0])) {
            player.move(x[1]) catch {};
        }
    }
}

const MovementKeys = .{
    .{ rl.KeyboardKey.key_up, .North },
    .{ rl.KeyboardKey.key_down, .South },
    .{ rl.KeyboardKey.key_left, .West },
    .{ rl.KeyboardKey.key_right, .East },
};

pub fn handleMouse() void {
    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        const px = vec.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };

        const uvec = graphics.pxToCell(px);
        var cell = terrain.getCellAtZYX(0, uvec.y, uvec.x);

        const tile = switch (cell.tile) {
            .Empty => terrain.Tile{ .Solid = .Stone },
            .Floor => terrain.Tile{ .Solid = .Stone },
            .Solid => terrain.Tile{ .Floor = .Dirt },
        };

        cell.tile = tile;
    }
}