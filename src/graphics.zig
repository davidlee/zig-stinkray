const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 15;
const MIDPOINT = 8;

var camera: rl.Camera2D = undefined;
var screenWidth: i32 = 0;
var screenHeight: i32 = 0;

var viewportWidth: usize = 80;
var viewportHeight: usize = 30;

pub fn init(world: *m.World) void {
    _ = world;
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    rl.setTargetFPS(60);
    screenWidth = rl.getScreenWidth();
    screenHeight = rl.getScreenHeight();
    const fw: f32 = @floatFromInt(screenWidth);
    const fh: f32 = @floatFromInt(screenHeight);

    camera = rl.Camera2D{
        .offset = rl.Vector2.init(fw / 2.0, fh / 2.0),
        .target = rl.Vector2.init(0, 0),
        .rotation = 0,
        .zoom = 1,
    };
}

pub fn deinit() void {
    defer rl.closeWindow();
}

// FIXME - if using a camera, we have to account for its translation
// NOTE doesn't check bounds
fn pxToCellXY(px: m.Ivec2) m.Uvec2 {
    return m.Uvec2{
        .x = @as(u16, @intCast(px.x)) / CELL_SIZE,
        .y = @as(u16, @intCast(px.y)) / CELL_SIZE,
    };
}

pub fn cellXYatMouse() m.Uvec2 {
    const px = m.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };
    return pxToCellXY(px);
}

pub fn draw(world: *m.World) void {
    // camera.target = cameraFollowPlayerTarget(world);
    const fw: f32 = @floatFromInt(screenWidth);
    const fh: f32 = @floatFromInt(screenHeight);
    camera.offset = rl.Vector2.init(fw / 2.0, fh / 2.0);
    camera.target = rl.Vector2.init(0, 0);
    camera.rotation = @as(f32, @floatFromInt(@intFromEnum(world.player.facing))) * 45.0;

    rl.clearBackground(rl.Color.dark_gray);
    camera.begin();

    drawCells(world) catch std.log.debug("ERR: DrawCells", .{});
    drawPlayer(&world.player);
    // drawRegion(world);

    camera.end();
}

fn drawPlayer(player: *p.Player) void {
    _ = player;
    rl.drawRectangle(0, 0, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn drawCells(world: *m.World) !void {
    var al = std.ArrayList(t.RectAddr).init(world.allocator);
    defer al.deinit();

    try world.cells.getRect(
        &al,
        world.player.pos.x,
        world.player.pos.y,
        world.player.z,
        viewportWidth,
        viewportHeight,
    );

    const cell_size: i32 = CELL_SIZE;
    const ax: i32 = 0 - m.cast(i32, viewportWidth / 2);
    const ay: i32 = 0 - m.cast(i32, viewportHeight / 2);

    rl.drawRectangle(ax * cell_size, ay * cell_size, m.cast(i32, viewportWidth) * cell_size, m.cast(i32, viewportHeight) * cell_size, rl.Color.init(10, 10, 10, 30));

    for (al.items) |it| {
        const cell = it.cell;

        const rel_pos = t.relativePos(world.player.pos, it.x, it.y) catch unreachable;

        const display_x: i32 = rel_pos.x * cell_size;
        const display_y: i32 = rel_pos.y * cell_size;

        switch (cell.tile) {
            .Empty => rl.drawRectangle(display_x, display_y, CELL_SIZE, CELL_SIZE, rl.Color.dark_gray),
            .Floor => |mat| {
                switch (mat) {
                    .Iron => {
                        rl.drawRectangle(display_x, display_y, CELL_SIZE, CELL_SIZE, rl.Color.init(20, 30, 20, 255));
                        rl.drawRectangle(display_x + 3, display_y + 3, 4, 4, rl.Color.init(50, 50, 40, 255));
                    },
                    else => {
                        rl.drawRectangle(display_x, display_y, CELL_SIZE, CELL_SIZE, rl.Color.init(48, 33, 22, 255));
                        rl.drawRectangle(display_x + 4, display_y + 4, 4, 4, rl.Color.init(18, 25, 44, 255));
                    },
                }
            },
            .Solid => rl.drawRectangle(display_x, display_y, CELL_SIZE, CELL_SIZE, rl.Color.black),
        }
    }
}
