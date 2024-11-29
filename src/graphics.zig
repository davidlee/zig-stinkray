const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 15;
const CELL_MIDPOINT: i32 = CELL_SIZE / 2;

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
    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    rl.setTargetFPS(60);
    screenWidth = rl.getScreenWidth();
    screenHeight = rl.getScreenHeight();
    const fw: f32 = @floatFromInt(screenWidth);
    const fh: f32 = @floatFromInt(screenHeight);

    camera = rl.Camera2D{
        .offset = rl.Vector2.init(fw / 2.0, fh / 2.0),
        .target = rl.Vector2.init(0, 0), // centered on the top left of player tile
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
    frame_count +%= 1;
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
    const o: f32 = @floatFromInt(CELL_SIZE / 2);
    const fc: i32 = @intCast(frame_count);
    const alpha = m.cast(u8, @abs(@rem(fc, 100) - 50) / 1);
    // draw a circle at visible range around the player
    rl.drawCircleLines(o, o, @floatFromInt(range * CELL_SIZE), rl.Color.init(0, 255, 0, alpha));
    drawRectangles(world);
}

fn drawRectangles(world: *m.World) void {
    const f = frame_count % world.rectangles.items.len;
    const rect = world.rectangles.items[f];
    const rel = t.relativePos(world.player.pos, rect.tl.x, rect.tl.y) catch unreachable;

    rl.drawRectangleLines(
        rel.x * CELL_SIZE,
        rel.y * CELL_SIZE,
        m.cast(i32, rect.br.x - rect.tl.x) * CELL_SIZE,
        m.cast(i32, rect.br.y - rect.tl.y) * CELL_SIZE,
        rl.Color.init(255, 0, 0, 250),
    );

    // find rectangles within range of the player and draw them
    _ = findWallVerticesNearPlayer(world, 12) catch unreachable;
}
const dist = struct { f32, m.Uvec2 };

fn findWallVerticesNearPlayer(world: *m.World, range: usize) !std.ArrayList(m.Uvec2) {
    var al = std.ArrayList(m.Uvec2).init(world.allocator);
    const pp = world.player.pos;

    defer al.deinit();

    var distances = std.ArrayList(dist).initCapacity(world.allocator, 2) catch unreachable;
    defer distances.deinit();

    for (world.rectangles.items) |rect| {
        const vertices = interestingVertices(rect, pp);

        for (vertices) |v| {
            const d = distanceUvec2(pp, v);
            distances.append(.{ d, v }) catch unreachable;
        }
    }

    std.mem.sort(dist, distances.items, {}, cmpDist);

    for (distances.items) |d| {
        std.debug.print("dist {d}\n", .{d[0]});
        if (d[0] < @as(f32, @floatFromInt(range))) {
            al.append(d[1]) catch unreachable;
            std.debug.print("++++ {d} {d}\n", .{ d[1].x, d[1].y });
            drawLineFromPlayerToPoint(world, d[1].x, d[1].y, 150);
        }
    }

    const d = al.items[frame_count % al.items.len];
    drawLineFromPlayerToPoint(world, d.x, d.y, 255);

    return al;
}

fn cmpDist(_: void, a: dist, b: dist) bool {
    return a[0] < b[0];
}

fn distanceUvec2(a: m.Uvec2, b: m.Uvec2) f32 {
    const ax: f32 = @floatFromInt(a.x);
    const ay: f32 = @floatFromInt(a.y);
    const bx: f32 = @floatFromInt(b.x);
    const by: f32 = @floatFromInt(b.y);
    return std.math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
}

fn interestingVertices(rect: m.URect, pp: m.Uvec2) [2]m.Uvec2 {
    const tl = rect.tl;
    const br = rect.br;
    const tr = m.Uvec2{ .x = br.x, .y = tl.y };
    const bl = m.Uvec2{ .x = tl.x, .y = br.y };
    const top = tl.y;
    const bot = br.y;
    const lft = tl.x;
    const rgt = br.x;

    if (bot < pp.y) { // above player
        if (rgt < pp.x) {
            // above left
            return [2]m.Uvec2{ tr, bl };
        } else if (lft > pp.x) {
            // above right
            return [2]m.Uvec2{ tl, br };
        } else {
            // above
            return [2]m.Uvec2{ bl, br };
        }
    } else if (top > pp.y) { // below player
        if (lft > pp.x) {
            // below right
            return [2]m.Uvec2{ bl, tr };
        } else if (rgt < pp.x) {
            // below left
            return [2]m.Uvec2{ tl, br };
        } else {
            // below
            return [2]m.Uvec2{ tl, tr };
        }
    } else { // rect is to one side of the player
        if (lft > pp.x) { // right of player
            return [2]m.Uvec2{ tl, bl };
        } else {
            return [2]m.Uvec2{ tr, br };
        }
    }
}

fn rectVertices(rect: m.URect) [4]m.Uvec2 {
    const tr = m.Uvec2{ .x = rect.br.x, .y = rect.tl.y };
    const bl = m.Uvec2{ .x = rect.tl.x, .y = rect.br.y };
    return [4]m.Uvec2{ rect.tl, tr, rect.br, bl };
}

fn drawLineFromPlayerToPoint(world: *m.World, x: usize, y: usize, alpha: u8) void {
    const rel = t.relativePos(world.player.pos, x, y) catch unreachable;

    const px = m.cast(i32, CELL_MIDPOINT);
    const py = m.cast(i32, CELL_MIDPOINT);

    const tx = m.cast(i32, rel.x * CELL_SIZE);
    const ty = m.cast(i32, rel.y * CELL_SIZE);

    rl.drawLine(px, py, tx, ty, rl.Color.init(255, 255, 0, alpha));
}
