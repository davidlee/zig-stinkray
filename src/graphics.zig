const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 15;
const MIDPOINT = 8;

var camera: rl.Camera2D = undefined;
pub var wheel: f32 = 0;
var screenWidth: i32 = 1800;
var screenHeight: i32 = 1600;

var viewportWidth: usize = 200;
var viewportHeight: usize = 200;

var viewport: rl.RenderTexture = undefined;

var frame_count: usize = 0;

pub fn init(world: *m.World) void {
    _ = world;
    frame_count +%= 1;
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    rl.setTargetFPS(60);
    screenWidth = rl.getScreenWidth();
    screenHeight = rl.getScreenHeight();
    const fw: f32 = @floatFromInt(screenWidth);
    const fh: f32 = @floatFromInt(screenHeight);

    // viewport = rl.loadRenderTexture(m.cast(i32, viewportWidth * CELL_SIZE), m.cast(i32, viewportHeight * CELL_SIZE));

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
    camera.rotation = @as(f32, @floatFromInt(@intFromEnum(world.player.facing))) * 45.0;
    const scaleFactor = 1.0 + (0.25 * wheel);
    // if (wheel < 0) scaleFactor = 1.0 / scaleFactor;
    camera.zoom = std.math.clamp(camera.zoom * scaleFactor, 0.425, 8.0);

    rl.beginDrawing();
    defer rl.endDrawing();

    // rl.beginTextureMode(viewport);
    rl.beginMode2D(camera);

    rl.clearBackground(rl.Color.dark_gray);

    drawCells(world) catch std.log.debug("ERR: DrawCells", .{});
    drawPlayer(&world.player);
    // drawRegion(world);

    drawVisibility(world, 15);

    rl.endMode2D();
    rl.endTextureMode();

    // rl.clearBackground(rl.Color.black);
    //rl.drawTexture(viewport.texture, 0, 0, rl.Color.white);
}

fn drawPlayer(player: *p.Player) void {
    _ = player;
    rl.drawRectangle(0, 0, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn xToRelI32(x: usize) i32 {
    return (m.cast(i32, x) - m.cast(i32, viewportWidth / 2)) * CELL_SIZE;
}

fn yToRelI32(y: usize) i32 {
    return (m.cast(i32, y) - m.cast(i32, viewportHeight / 2)) * CELL_SIZE;
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
    const ax = xToRelI32(0);
    const ay = yToRelI32(0);

    rl.drawRectangle(
        ax,
        ay,
        m.cast(i32, viewportWidth) * cell_size,
        m.cast(i32, viewportHeight) * cell_size,
        rl.Color.black,
    );

    for (al.items) |it| {
        const cell = it.cell;

        const rel_pos = t.relativePos(world.player.pos, it.x, it.y) catch unreachable;

        if (rel_pos.x > viewportWidth / 2 or rel_pos.y > viewportHeight / 2) {
            std.debug.print("skipping {d} {d}\n", .{ rel_pos.x, rel_pos.y });
            continue;
        }

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

fn drawVisibility(world: *m.World, range: usize) void {
    // draw a circle at visible range around the player
    rl.drawCircleLines(0, 0, @floatFromInt(range * CELL_SIZE), rl.Color.green);
    rl.drawLine(0, 0, 100, 100, rl.Color.green);
    drawRectangles(world);
}

fn drawRectangles(world: *m.World) void {
    for (world.rectangles.items) |rect| {
        // std.debug.print("rect {d} {d} {d} {d}\n", .{ rect.tl.x, rect.tl.y, rect.br.x, rect.br.y });
        const rel = t.relativePos(world.player.pos, rect.tl.x, rect.tl.y) catch unreachable;
        rl.drawRectangleLines(
            rel.x * CELL_SIZE,
            rel.y * CELL_SIZE,
            m.cast(i32, rect.br.x - rect.tl.x) * CELL_SIZE,
            m.cast(i32, rect.br.y - rect.tl.y) * CELL_SIZE,
            rl.Color.init(255, 0, 0, 250),
        );
    }
}
