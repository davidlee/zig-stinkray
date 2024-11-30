const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE: i32 = 15;
const CELL_MIDPOINT: i32 = CELL_SIZE / 2;

const CELL_SIZE_F: f32 = @floatFromInt(CELL_SIZE);
const CELL_MIDPOINT_F: f32 = CELL_SIZE_F / 2.0;

var camera: rl.Camera2D = undefined;
pub var wheel: f32 = 0;

pub var screenWidth: i32 = 1800;
pub var screenHeight: i32 = 1600;
var viewportWidth: usize = 80;
var viewportHeight: usize = 80;
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

//
// draw functions
//

pub fn draw(world: *m.World) void {
    frame_count +%= 1;
    const scaleFactor = 1.0 + (0.25 * wheel);
    camera.rotation = -world.player.rotation;
    camera.zoom = std.math.clamp(camera.zoom * scaleFactor, 0.425, 8.0);
    camera.target = rl.Vector2.init(world.player.position.x * CELL_SIZE, world.player.position.y * CELL_SIZE);

    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);
    rl.beginMode2D(camera);
    {
        drawCells(world) catch unreachable;
        drawPlayer(&world.player);
        drawVisibility(world, 15);
    }
    rl.endMode2D();
}

fn drawPlayer(player: *p.Player) void {
    const coords = playerPxOrigin(&player.position);
    rl.drawRectangle(coords.x, coords.y, CELL_SIZE, CELL_SIZE, rl.Color.red);
}

fn drawCells(world: *m.World) !void {
    var al = std.ArrayList(t.RectAddr).init(world.allocator);
    defer al.deinit();

    const pos = world.player.position.uvec3();
    world.cells.getRect(
        &al,
        pos.x,
        pos.y,
        pos.z,
        viewportWidth,
        viewportHeight,
    );

    for (al.items) |it| {
        drawCell(&it.cell, it.x, it.y);
    }
}

fn drawCell(cell: *const t.Cell, x: usize, y: usize) void {
    const display_x: i32 = m.cast(i32, x) * CELL_SIZE;
    const display_y: i32 = m.cast(i32, y) * CELL_SIZE;
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

fn drawVisibility(world: *m.World, range: usize) void {
    const pp = playerPxOrigin(&world.player.position);
    const fc: i32 = @intCast(frame_count);
    const alpha = m.cast(u8, @abs(@rem(fc, 100) - 50) / 1);
    const k: i32 = m.cast(i32, range * CELL_SIZE * 2);
    // draw a circle at visible range around the player
    rl.drawCircleLines(pp.x, pp.y, @floatFromInt(range * CELL_SIZE), rl.Color.init(0, 255, 0, alpha));
    rl.drawRectangleLines(
        pp.x - @divFloor(k, 2),
        pp.y - @divFloor(k, 2),
        k,
        k,
        rl.Color.init(255, 255, 0, alpha),
    );
    drawRectangles(world);
    // find rectangles within range of the player and draw them
    drawEdgeVerticesNearPlayer(world, range);
}

fn drawRectangles(world: *m.World) void {
    for (world.rectangles.items) |r| {
        rl.drawRectangleLines(
            m.cast(i32, r.tl.x * CELL_SIZE),
            m.cast(i32, r.tl.y * CELL_SIZE),
            m.cast(i32, (r.br.x - r.tl.x) * CELL_SIZE),
            m.cast(i32, (r.br.y - r.tl.y) * CELL_SIZE),
            rl.Color.init(0, 255, 0, m.cast(u8, frame_count % 100)),
        );
    }
}
const distWithPoint = struct { f32, m.Uvec2 };

fn drawEdgeVerticesNearPlayer(world: *m.World, range: usize) void {
    var al = std.ArrayList(m.Uvec2).init(world.allocator);
    defer al.deinit();

    findEdgeVerticesNearPlayer(world, &al, range);

    if (al.items.len > 0) {
        const d = al.items[frame_count % al.items.len];
        drawLineFromPlayerTo(world, d.x, d.y, 40);
    }
}

//
// utility functions
//

// TODO this should find vertices within range as a bounding box, not a radius.
fn findEdgeVerticesNearPlayer(world: *m.World, arraylist: *std.ArrayList(m.Uvec2), range: usize) void {
    var distances = std.ArrayList(distWithPoint).init(world.allocator);
    defer distances.deinit();

    const pp = world.player.position.uvec2();

    // TODO pre-cull, cache, or pre-sort proximate rectangles to avoid
    // implausible performance on very large maps.
    // look into spatial hashing / spatial indexing.

    for (world.rectangles.items) |rect| {
        const vertices = getRectEdgeVertices(rect, pp);

        for (vertices) |v| {
            const d = distanceOfUvec2s(pp, v);
            if (d < m.flint(f32, range)) {
                distances.append(.{ d, v }) catch unreachable;
            }
        }
    }
    std.mem.sort(distWithPoint, distances.items, {}, cmpDist);

    for (distances.items) |d| {
        if (d[0] < @as(f32, @floatFromInt(range))) {
            arraylist.append(d[1]) catch unreachable;
            if (true) { // draw debug lines
                drawLineFromPlayerTo(world, d[1].x, d[1].y, 40);
                drawLineFromPlayerThrough(world, d[1].x, d[1].y, m.cast(i32, range));
            }
        }
    }
}

// there must be a better way to do this,
// but it has the virtue of being easy enough
// to understand that I could figure it out myself.
//
// non-enclosing rect bounds fall wholly to the NE/SE/SW/NW,
// or to either side and N/S/E/W.
// based on this, we can figure out which vertices will mark the
// edge, or side, of the rectangle as seen from the player's position.

// TODO return 3 vertices when rect is diagonal to the player.

fn getRectEdgeVertices(rect: m.URect, pp: m.Uvec2) [2]m.Uvec2 {
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

fn drawLineFromPlayerTo(world: *m.World, x: usize, y: usize, alpha: u8) void {
    const ppx = playerPxCentre(&world.player.position);
    const pt = m.Ivec2{
        .x = m.cast(i32, x * CELL_SIZE),
        .y = m.cast(i32, y * CELL_SIZE),
    };
    rl.drawLine(ppx.x, ppx.y, pt.x, pt.y, rl.Color.init(255, 255, 0, alpha));
}

fn drawLineFromPlayerThrough(world: *m.World, x: usize, y: usize, range: i32) void {
    const angle: f32 = angleFromPlayerTo(world, x, y);
    const ppx = playerPxCentre(&world.player.position);

    rl.drawLine(
        ppx.x,
        ppx.y,
        ppx.x + @as(i32, @as(i32, @intFromFloat(std.math.cos(angle))) * m.cast(i32, range)),
        ppx.y + @as(i32, @as(i32, @intFromFloat(std.math.sin(angle))) * m.cast(i32, range)),
        rl.Color.init(255, 255, 40, 40),
    );
}

fn angleFromPlayerTo(world: *m.World, x: usize, y: usize) f32 {
    const tx = m.flint(f32, x * CELL_SIZE);
    const ty = m.flint(f32, y * CELL_SIZE);
    const px = world.player.position.x * CELL_SIZE_F + CELL_MIDPOINT_F;
    const py = world.player.position.y * CELL_SIZE_F + CELL_MIDPOINT_F;
    return std.math.atan2(
        ty - py,
        tx - px,
    );
}

pub fn playerPxOrigin(position: *m.Vec3) m.Ivec2 {
    const x: i32 = @intFromFloat(position.x * CELL_SIZE);
    const y: i32 = @intFromFloat(position.y * CELL_SIZE);
    return m.Ivec2{ .x = x, .y = y };
}

pub fn playerPxCentre(position: *m.Vec3) m.Ivec2 {
    const x: i32 = @intFromFloat(position.x * CELL_SIZE_F + CELL_MIDPOINT_F);
    const y: i32 = @intFromFloat(position.y * CELL_SIZE_F + CELL_MIDPOINT_F);
    return m.Ivec2{ .x = x, .y = y };
}

fn cmpDist(_: void, a: distWithPoint, b: distWithPoint) bool {
    return a[0] < b[0];
}

fn distanceOfUvec2s(a: m.Uvec2, b: m.Uvec2) f32 {
    const ax: f32 = @floatFromInt(a.x);
    const ay: f32 = @floatFromInt(a.y);
    const bx: f32 = @floatFromInt(b.x);
    const by: f32 = @floatFromInt(b.y);
    return std.math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
}
