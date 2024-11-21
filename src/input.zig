const std = @import("std");
const rl = @import("raylib");

const logic = @import("logic.zig");
const graphics = @import("graphics.zig");

pub fn handleKeyboard() void {
    inline for (MovementKeys) |x| {
        if (rl.isKeyDown(x[0])) logic.player.move = x[1];
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
        const x = rl.getMouseX();
        const y = rl.getMouseY();

        const px = logic.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };
        const yx = graphics.pxToCell(px);

        _ = .{ x, y, yx };

        // var cell = logic.cells.tdata[0][yx.y][yx.x];
        // _ = cell;
        // switch()
        // std.debug.print("clik {d} - {d}", .{ x, y });
        // std.debug.print("cell: {d} - {d}", .{ cell.x, cell.y });
    }
}
