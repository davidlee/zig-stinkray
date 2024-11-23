const std = @import("std");
const rl = @import("raylib");

const vec = @import("vec.zig");
const logic = @import("logic.zig");
const p = @import("player.zig");
const t = @import("terrain.zig");

pub const CELL_SIZE = 16;

pub fn init(alloc: std.mem.Allocator) void {
    _ = alloc;

    const screenWidth = 2048;
    const screenHeight = 2048;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");

    rl.setTargetFPS(60);
}

pub fn deinit() void {
    defer rl.closeWindow();
}

pub fn pxToCell(px: vec.Ivec2) vec.Uvec2 {
    return vec.Uvec2{
        .x = @as(u16, @intCast(px.x)) / CELL_SIZE,
        .y = @as(u16, @intCast(px.y)) / CELL_SIZE,
    };
}

// Main game loop
pub fn startRunLoop(alloc: std.mem.Allocator) void {
    while (!rl.windowShouldClose()) {
        logic.tick(alloc);

        rl.beginDrawing();
        defer rl.endDrawing();

        draw();
    }
}

fn draw() void {
    rl.clearBackground(rl.Color.dark_gray);
    drawCells(t.cells);
    drawPlayer(p.player);
}

fn drawPlayer(player: p.Player) void {
    const x = player.pos.x * CELL_SIZE;
    const y = player.pos.y * CELL_SIZE;

    rl.drawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn drawCells(cells: t.Cells) void {
    const z = 0;
    for (cells.data[z], 0..) |ys, y| {
        for (ys, 0..) |cell, x| {
            const rx: i32 = @intCast(x * CELL_SIZE);
            const ry: i32 = @intCast(y * CELL_SIZE);

            switch (cell.tile) {
                .Empty => {},
                .Floor => rl.drawRectangle(rx, ry, CELL_SIZE, CELL_SIZE, rl.Color.dark_brown),
                .Solid => rl.drawRectangle(rx, ry, CELL_SIZE, CELL_SIZE, rl.Color.black),
            }
        }
    }
}
