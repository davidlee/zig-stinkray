const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE: i32 = 15;
const CELL_MIDPOINT: i32 = CELL_SIZE / 2;

const CELL_SIZE_F: f32 = @floatFromInt(CELL_SIZE);
const CELL_MIDPOINT_F: f32 = CELL_SIZE_F / 2.0;
const light_radius: usize = 15;

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
        drawVisibilityPolygon(world, light_radius);
        drawVisibilityDebug(world, light_radius);
    }
    rl.endMode2D();
}

fn drawPlayer(player: *p.Player) void {
    const x: i32 = @intFromFloat(player.position.x * CELL_SIZE);
    const y: i32 = @intFromFloat(player.position.y * CELL_SIZE);
    rl.drawRectangle(x, y, CELL_SIZE, CELL_SIZE, rl.Color.red);
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

// sweep a line from the player's position across the screen
// and fill in the triangles generated by the rays as they intersect walls.

// 1. Calculate the angles where walls begin or end.
// 2. Cast a ray from the center along each angle.
// 3. Fill in the triangles generated by those rays.

// In more detail:

// var endpoints;   # list of endpoints, sorted by angle
// var open = [];   # list of walls the sweep line intersects

// loop over endpoints:
//     remember which wall is nearest
//     add any walls that BEGIN at this endpoint to 'walls'
//     remove any walls that END at this endpoint from 'walls'

//     figure out which wall is now nearest
//     if the nearest wall changed:
//         fill the current triangle and begin a new one

// data structures:
//
// Output is an arraylist of Vec2 which form a visible area polygon.

// These are currently 'open' line segments, sorted so that the nearest
// segment is first. It's used only during the sweep algorithm, and exposed
// as a public field here so that the demo can display it.
// public var open:DLL<Segment>;

fn drawVisibilityPolygon(world: *m.World, range: usize) void {
    // FIXME we should track the player's centre in position, not the top left of the tile.
    const viewpoint: m.Vec2 = .{ .x = world.player.position.x + 0.5, .y = world.player.position.y + 0.5 };

    var output = std.ArrayList(m.Vec2).init(world.allocator);
    defer output.deinit();

    _ = .{ range, output, viewpoint };
    // return output
}

fn drawVisibilityDebug(world: *m.World, range: usize) void {
    const px: i32 = @intFromFloat(world.player.position.x * CELL_SIZE);
    const py: i32 = @intFromFloat(world.player.position.y * CELL_SIZE);

    const fc: i32 = @intCast(frame_count);
    const alpha = m.cast(u8, @abs(@rem(fc, 100) - 50) / 1);
    const k: i32 = m.cast(i32, range * CELL_SIZE * 2);
    // draw a circle at visible range around the player
    rl.drawCircleLines(px, py, @floatFromInt(range * CELL_SIZE), rl.Color.init(0, 255, 0, alpha));
    rl.drawRectangleLines(
        px - @divFloor(k, 2),
        py - @divFloor(k, 2),
        k,
        k,
        rl.Color.init(255, 255, 0, alpha),
    );
    drawRectangles(world);
    // find rectangles within range of the player and draw them
    drawEdgeVerticesNearPlayer(world, range);
    drawLineFromPlayerTo(world, 0, 0, 255);
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
        const vertices = getRectEdgeVertices(world, rect);

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
                drawLineFromPlayerThrough(world, d[1].x, d[1].y, m.cast(i32, range * 1000), 40);
            }
        }
    }
}

fn getRectEdgeVertices(world: *m.World, rect: m.URect) [2]m.Uvec2 {
    const px = world.player.position.x;
    const py = world.player.position.y;

    const tl = rect.tl;
    const br = rect.br;
    const tr = m.Uvec2{ .x = br.x, .y = tl.y };
    const bl = m.Uvec2{ .x = tl.x, .y = br.y };

    const rel_x: f32 = m.flint(f32, tl.x) - px;
    const rel_y: f32 = m.flint(f32, tl.y) - py;
    const q1 = m.quadrant(rel_x, rel_y);

    const rel_x2: f32 = m.flint(f32, br.x) - px;
    const rel_y2: f32 = m.flint(f32, br.y) - py;
    const q2 = m.quadrant(rel_x2, rel_y2);

    // TODO return 3 vertices when rect is diagonal to the player.
    // TODO figure out how to return variable length array - should I use a null or an arraylist?

    if (q1 == q2) { // rect wholly in one quadrant
        return switch (q1) {
            .q_I => [2]m.Uvec2{ tl, br },
            .q_II => [2]m.Uvec2{ tr, bl },
            .q_III => [2]m.Uvec2{ tl, br },
            .q_IV => [2]m.Uvec2{ tr, bl },
            .none => unreachable,
        };
    } else { // rect spans two quadrants; is in one of the four cardinal directions
        if (rel_x2 < 0) { // left of player
            return [2]m.Uvec2{ tr, br };
        } else if (rel_x > 0) { // right of player
            return [2]m.Uvec2{ tl, bl };
        } else if (rel_y2 < 0) { // above player
            return [2]m.Uvec2{ bl, br };
        } else if (rel_y > 0) { // below player
            return [2]m.Uvec2{ tl, tr };
        }
    }
    unreachable;
}

fn drawLineFromPlayerTo(world: *m.World, x: usize, y: usize, alpha: u8) void {
    const ppx = playerPxCentre(&world.player.position);
    const pt = m.Ivec2{
        .x = m.cast(i32, x * CELL_SIZE),
        .y = m.cast(i32, y * CELL_SIZE),
    };
    rl.drawLine(ppx.x, ppx.y, pt.x, pt.y, rl.Color.init(255, 255, 0, alpha));
}

fn drawLineFromPlayerThrough(world: *m.World, x: usize, y: usize, range: i32, alpha: u8) void {
    const px: f32 = world.player.position.x * CELL_SIZE_F + CELL_MIDPOINT_F;
    const py: f32 = world.player.position.y * CELL_SIZE_F + CELL_MIDPOINT_F;
    const angle: f32 = angleBetweenPoints(px, py, m.flint(f32, x) * CELL_SIZE_F, m.flint(f32, y) * CELL_SIZE_F);

    const tx_f: f32 = px + std.math.cos(angle) * m.flint(f32, range);
    const ty_f: f32 = py + std.math.sin(angle) * m.flint(f32, range);

    const tx: i32 = @intFromFloat(tx_f);
    const ty: i32 = @intFromFloat(ty_f);

    rl.drawLine(@intFromFloat(px), @intFromFloat(py), tx, ty, rl.Color.init(0, 255, 255, alpha));
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

fn angleBetweenPoints(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    return std.math.atan2(y2 - y1, x2 - x1);
}

// WARN this loses precision, don't use for angle calculations.
// pub fn playerPxOrigin(position: *m.Vec3) m.Ivec2 {
//     const x: i32 = @intFromFloat(position.x * CELL_SIZE);
//     const y: i32 = @intFromFloat(position.y * CELL_SIZE);
//     return m.Ivec2{ .x = x, .y = y };
// }

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
