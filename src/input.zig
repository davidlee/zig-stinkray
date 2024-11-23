const std = @import("std");
const rl = @import("raylib");
const logic = @import("logic.zig");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const vec = @import("vec.zig");
const main = @import("main.zig");
const p = @import("player.zig");

// https://github.com/Not-Nik/raylib-zig/blob/devel/lib/preludes/raylib-prelude.zig
// would be nice if autocomplete was working for raylib ..

pub fn handleKeyboard(world: *main.World) void {
    inline for (MovementKeys, 0..) |x, i| {
        if (rl.isKeyPressed(x[0]) or rl.isKeyPressedRepeat(x[0])) {
            if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
                world.player.moveTo(world, p.OrdinalDirections[i]) catch {};
            } else {
                world.player.moveTo(world, x[1]) catch {};
            }
        }
    }

    if (rl.isKeyPressed(.key_q)) {}
}

const MovementKeys = .{
    .{ rl.KeyboardKey.key_up, .North },
    .{ rl.KeyboardKey.key_right, .East },
    .{ rl.KeyboardKey.key_down, .South },
    .{ rl.KeyboardKey.key_left, .West },
};

pub fn handleMouse(world: *main.World) void {
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
