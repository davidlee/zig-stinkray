const std = @import("std");
const rl = @import("raylib");

const logic = @import("logic.zig");

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
    rl.clearBackground(rl.Color.white);
    drawCells(logic.cells);
}

fn drawCells(cells: logic.Cells) void {
    const cellSize = 16;
    const z = 0;
    for (cells.data[z], 0..) |ys, y| {
        for (ys, 0..) |cell, x| {
            switch (cell.tile) {
                .Empty => {},
                .Floor => rl.drawRectangle(@intCast(x * cellSize), @intCast(y * cellSize), cellSize, cellSize, rl.Color.dark_brown),
                .Solid => rl.drawRectangle(@intCast(x * cellSize), @intCast(y * cellSize), cellSize, cellSize, rl.Color.black),
            }
        }
    }
}
