const std = @import("std");
const rl = @import("raylib");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const m = @import("main.zig");
const p = @import("player.zig");

// constants here (TODO LSP autocomplete for them?)
// https://github.com/Not-Nik/raylib-zig/blob/devel/lib/preludes/raylib-prelude.zig

pub fn handleKeyboard(world: *m.World) void {
    inline for (MovementKeys, 0..) |x, i| {
        if (rl.isKeyPressed(x[0]) or rl.isKeyPressedRepeat(x[0])) {
            if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
                world.player.moveTo(world, m.OrdinalDirections[i]) catch {};
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

pub fn handleMouse(world: *m.World) !void {
    if (rl.isMouseButtonPressed(rl.MouseButton.mouse_button_left)) {
        const px = m.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };
        const uvec = graphics.pxToCellXY(px);

        // std.debug.print(" ({d}, {d}) ", .{ uvec.x, uvec.y });

        const cell = try world.cells.get(uvec.x, uvec.y, 0);

        const tile = switch (cell.tile) {
            .Empty => terrain.Tile{ .Solid = .Stone },
            .Floor => terrain.Tile{ .Solid = .Stone },
            .Solid => terrain.Tile{ .Floor = .Dirt },
        };

        const new_cell = terrain.Cell{ .tile = tile };
        try world.cells.set(uvec.x, uvec.y, 0, new_cell);
    }
}
