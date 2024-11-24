const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 16;

var camera: rl.Camera2D = undefined; // hhhnnnnggg

pub fn init(world: *m.World) void {
    _ = world;
    const screenWidth = 2048;
    const screenHeight = 2048;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    camera = rl.Camera2D{
        .offset = rl.Vector2.init(
            @floatFromInt(screenWidth / 2),
            @floatFromInt(screenHeight / 2),
        ),
        .target = rl.Vector2.init(0, 0
        // @floatFromInt(world.player.pos.x * CELL_SIZE),
        // @floatFromInt(world.player.pos.y * CELL_SIZE),
        ),
        .rotation = 0,
        .zoom = 1,
    };

    _ = camera;
    rl.setTargetFPS(60);
}

fn playerFollowCameraTarget(world: *m.World) rl.Vector2 {
    const x = world.player.pos.x * CELL_SIZE;
    const y = world.player.pos.y * CELL_SIZE;

    return rl.Vector2.init(
        @floatFromInt(x),
        @floatFromInt(y),
    );
}

pub fn deinit() void {
    defer rl.closeWindow();
}

// TODO - if using a camera, we have to account for its translation
fn pxToCellXY(px: m.Ivec2) m.Uvec2 {
    return m.Uvec2{
        .x = @as(u16, @intCast(px.x)) / CELL_SIZE,
        .y = @as(u16, @intCast(px.y)) / CELL_SIZE,
    };
}

// NOTE doesn't check it's valid
pub fn cellXYatMouse() m.Uvec2 {
    const px = m.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };
    return pxToCellXY(px);
}

pub fn draw(world: *m.World) void {
    rl.clearBackground(rl.Color.dark_gray);
    camera.begin();
    camera.target = playerFollowCameraTarget(world);
    drawCells(&world.cells) catch std.log.debug("ERR: DrawCells", .{});
    drawPlayer(&world.player);
    camera.end();
}

fn drawPlayer(player: *p.Player) void {
    const x = player.pos.x * CELL_SIZE;
    const y = player.pos.y * CELL_SIZE;

    rl.drawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn drawCells(cells: *t.CellStore) !void {
    // TODO only draw visible cells
    // or at least on the same Z index ..
    for (cells._list, 0..) |cell, i| {
        const xy = try cells.XYZof(i);

        const px: i32 = @intCast(xy[0] * CELL_SIZE);
        const py: i32 = @intCast(xy[1] * CELL_SIZE);

        switch (cell.tile) {
            .Empty => rl.drawRectangle(px, py, CELL_SIZE, CELL_SIZE, rl.Color.dark_green),
            .Floor => |mat| {
                switch (mat) {
                    .Iron => rl.drawRectangle(px, py, CELL_SIZE, CELL_SIZE, rl.Color.yellow),
                    else => rl.drawRectangle(px, py, CELL_SIZE, CELL_SIZE, rl.Color.dark_brown),
                }
            },
            .Solid => rl.drawRectangle(px, py, CELL_SIZE, CELL_SIZE, rl.Color.orange),
        }
    }
}
