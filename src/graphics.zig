const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 16;

pub fn init(world: *m.World) void {
    _ = world;

    const screenWidth = 2048;
    const screenHeight = 2048;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.setTargetFPS(60);
}

pub fn deinit() void {
    defer rl.closeWindow();
}

pub fn pxToCell(px: m.Ivec2) m.Uvec2 {
    return m.Uvec2{
        .x = @as(u16, @intCast(px.x)) / CELL_SIZE,
        .y = @as(u16, @intCast(px.y)) / CELL_SIZE,
    };
}

pub fn draw(world: *m.World) void {
    rl.clearBackground(rl.Color.dark_gray);
    drawCells(&world.cells);
    drawPlayer(&world.player);
}

fn drawPlayer(player: *p.Player) void {
    const x = player.pos.x * CELL_SIZE;
    const y = player.pos.y * CELL_SIZE;

    rl.drawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn drawCells(cells: *t.CellStore) void {
    // TODO only draw visible cells
    for (cells.list, 0..) |cell, i| {
        const xy = cells.indexToXYZ(i);

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
