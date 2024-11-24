const std = @import("std");
const rl = @import("raylib");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const m = @import("main.zig");
const p = @import("player.zig");

// constants here (TODO LSP autocomplete for them?)
// https://github.com/Not-Nik/raylib-zig/blob/devel/lib/preludes/raylib-prelude.zig

pub fn handleKeyboard(world: *m.World) void {
    const facing_dir_index: isize = @intFromEnum(world.player.facing);

    inline for (MovementKeys, 0..) |x, i| {
        if (rl.isKeyPressed(x[0]) or rl.isKeyPressedRepeat(x[0])) {
            var dir: m.Direction = undefined;
            if (rl.isKeyDown(rl.KeyboardKey.key_left_shift)) {
                dir = m.OrdinalDirections[i];
            } else {
                dir = x[1];
            }
            if (facing_dir_index != 0) {
                // dear god, the casting sytax is horrible
                // this is just adjusting the movement direction according to player rotation.

                // const j: usize = @intCast(@rem((@intFromEnum(dir) + @as(isize, @intCast(m.DirectionList.len)) - facing_dir_index), m.DirectionList.len));

                const move_dir_index: isize = @intFromEnum(dir);
                const arr_len: isize = m.DirectionList.len;
                const j: usize = @intCast(@rem(move_dir_index + arr_len - facing_dir_index, arr_len));

                dir = m.DirectionList[j];
            }
            world.player.moveTo(world, dir) catch {};
        }
    }

    if (rl.isKeyPressed(.key_one)) {
        const new_facing = m.RotationalDirection.Counterclockwise.applyToFacing(world.player.facing);
        world.player.facing = new_facing;
    }

    if (rl.isKeyPressed(.key_two)) {
        const new_facing = m.RotationalDirection.Clockwise.applyToFacing(world.player.facing);
        world.player.facing = new_facing;
    }
}

const MovementKeys = .{
    .{ rl.KeyboardKey.key_up, .North },
    .{ rl.KeyboardKey.key_right, .East },
    .{ rl.KeyboardKey.key_down, .South },
    .{ rl.KeyboardKey.key_left, .West },
};

pub fn handleMouse(world: *m.World) !void {
    world.region.clearAndFree();
    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {
        try world.cells.squareAround(world.player.pos.x, world.player.pos.y, 5, &world.region);
    }
}
