const std = @import("std");
const rl = @import("raylib");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const m = @import("main.zig");
const p = @import("player.zig");

// constants here (TODO LSP autocomplete for them?)
// https://github.com/Not-Nik/raylib-zig/blob/devel/lib/preludes/raylib-prelude.zig

pub fn handleKeyboard(world: *m.World) void {
    inline for (MovementKeys) |x| {
        if (rl.isKeyPressed(x[0]) or rl.isKeyPressedRepeat(x[0])) {
            const dir = x[1];
            world.player.move(world, dir) catch {
                std.log.debug("move to {s} {d},{d} failed", .{ @tagName(dir), world.player.position.x, world.player.position.y });
            };
        }
    }

    // if (rl.isKeyPressed(.key_one)) {
    //     const new_facing = m.RotationalDirection.Counterclockwise.applyToFacing(world.player.facing);
    //     world.player.facing = new_facing;
    // }

    // if (rl.isKeyPressed(.key_two)) {
    //     const new_facing = m.RotationalDirection.Clockwise.applyToFacing(world.player.facing);
    //     world.player.facing = new_facing;
    // }
}

const MovementKeys = .{
    .{ rl.KeyboardKey.key_up, .Forward },
    .{ rl.KeyboardKey.key_right, .Right },
    .{ rl.KeyboardKey.key_down, .Backward },
    .{ rl.KeyboardKey.key_left, .Left },
};

pub fn handleMouse(world: *m.World) !void {
    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_left)) {}

    // say mouse x while holding RMB rotates the player
    // and mouse y changes your speed (creeping, walking, running, sprinting)
    // endurance is a whole thing

    if (rl.isMouseButtonDown(rl.MouseButton.mouse_button_right)) {
        const rotation: f32 = m.flint(f32, rl.getMouseX()) / m.flint(f32, graphics.screenWidth) * 360.0;
        world.player.rotation = rotation;
    }

    graphics.wheel = rl.getMouseWheelMove();
}
