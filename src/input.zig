const std = @import("std");
const rl = @import("raylib");
const graphics = @import("graphics.zig");
const terrain = @import("terrain.zig");
const m = @import("main.zig");
const p = @import("player.zig");

// constants here (TODO LSP autocomplete for them?)
// https://github.com/Not-Nik/raylib-zig/blob/devel/lib/preludes/raylib-prelude.zig

fn keyPress(key: rl.KeyboardKey) bool {
    return (rl.isKeyDown(key) or rl.isKeyPressedRepeat(key));
    // return (rl.isKeyPressed(key) or rl.isKeyPressedRepeat(key));
}

pub fn handleKeyboard(world: *m.World) void {
    if (keyPress(.key_up)) {
        world.player.move(world, .Forward);
    }

    if (keyPress(.key_down)) {
        world.player.move(world, .Backward);
    }

    if (keyPress(.key_left)) {
        world.player.turn(.Left);
    }

    if (keyPress(.key_right)) {
        world.player.turn(.Right);
    }
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
