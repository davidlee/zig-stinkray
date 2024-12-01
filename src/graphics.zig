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
    const x: i32 = @intFromFloat(player.position.x * CELL_SIZE - CELL_MIDPOINT_F);
    const y: i32 = @intFromFloat(player.position.y * CELL_SIZE - CELL_MIDPOINT_F);
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
    const viewpoint: m.Vec2 = .{ .x = world.player.position.x, .y = world.player.position.y };

    var output = std.ArrayList(m.Vec2).init(world.allocator);
    defer output.deinit();

    var rects = std.ArrayList(m.URect).init(world.allocator);
    defer rects.deinit();
    findRectsIntersectingSquareAround(world, &rects, viewpoint.x, viewpoint.y, range);

    var segments = std.ArrayList(m.WallSegment).init(world.allocator);
    defer segments.deinit();
    findWallSegmentsInBoundingBox(world, &segments, viewpoint.x, viewpoint.y, range);

    // for (rects.items) |rect| {
    //     const verts = getRectEdgeVertices(world, rect, viewpoint.x, viewpoint.y);
    //     for (verts) |maybe_v| {
    //         if (maybe_v) |v| {
    //             drawLineFromPlayerTo(world, v.x, v.y, 40);
    //             drawLineToBoundingBox(world, v.x, v.y, m.cast(i32, range * CELL_SIZE), 40);
    //         }
    //     }
    // }

    for (segments.items) |s| {
        drawLineFromPlayerTo(world, m.intf(usize, s.p1.x), m.intf(usize, s.p1.y), 255);
        drawLineFromPlayerTo(world, m.intf(usize, s.p2.x), m.intf(usize, s.p2.y), 255);
        // std.debug.print("SEGMENTS :: {d} {d} {d} {d}\n", .{ s.p1.x, s.p1.y, s.p2.x, s.p2.y });
        rl.drawLine(
            m.intf(i32, s.p1.x * CELL_SIZE),
            m.intf(i32, s.p1.y * CELL_SIZE),
            m.intf(i32, s.p2.x * CELL_SIZE),
            m.intf(i32, s.p2.y * CELL_SIZE),
            rl.Color.init(255, 255, 0, 255),
        );
    }

    if (rects.items.len > 0) {
        const rect = rects.items[frame_count % rects.items.len];
        const alpha: u8 = m.cast(u8, @abs(m.cast(i32, frame_count % 100) - 50));
        rl.drawRectangle(
            m.cast(i32, rect.tl.x * CELL_SIZE),
            m.cast(i32, rect.tl.y * CELL_SIZE),
            m.cast(i32, (rect.br.x - rect.tl.x) * CELL_SIZE),
            m.cast(i32, (rect.br.y - rect.tl.y) * CELL_SIZE),
            rl.Color.init(0, 255, 0, alpha),
        );
    }
    // getWallsFacing(world, &rects, m.flint(f32, r.tl.x), m.flint(f32, r.tl.y));
    // TODOi

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
const distWithPoint = struct {
    f32,
    m.Uvec2,
};

fn cmpDistWithPoint(_: void, a: distWithPoint, b: distWithPoint) bool {
    return a[0] < b[0];
}

fn drawEdgeVerticesNearPlayer(world: *m.World, range: usize) void {
    var al = std.ArrayList(m.Uvec2).init(world.allocator);
    defer al.deinit();

    findEdgeVerticesNearPlayer(world, &al, range);

    if (al.items.len > 0) {
        const d = al.items[frame_count % al.items.len];
        drawLineFromPlayerTo(world, d.x, d.y, 40);
    }
}

fn findWallSegmentsInBoundingBox(world: *m.World, array_list: *std.ArrayList(m.WallSegment), x: f32, y: f32, range: usize) void {
    const r: f32 = @floatFromInt(range);
    const bx1 = x - r;
    const bx2 = x + r;
    const by1 = y - r;
    const by2 = y + r;

    var segs: [4]m.WallSegment = undefined;

    var first: m.WallSegment = undefined; // top
    var intersecting: bool = false;
    var i: usize = 0;

    for (world.wall_segments.items) |*s| {
        if (s.p1.top_left) {
            first = s.*;
            segs = .{ first, undefined, undefined, undefined };
            intersecting = false;
            i = 0;
        } else {
            i += 1;
            segs[i] = s.*;
        }

        if (!intersecting) {
            if (rectIntersectsPoint(bx1, by1, bx2, by2, s.p1.x, s.p1.y) or
                rectIntersectsPoint(bx1, by1, bx2, by2, s.p2.x, s.p2.y))
            {
                intersecting = true;
            }
        }

        if (intersecting and i == 3) {
            var walls = std.ArrayList(m.WallSegment).init(world.allocator);
            defer walls.deinit();

            // determine facing walls based on relative position to player at x,y
            const tl = segs[0].p1;
            const br = segs[2].p2;

            const top = segs[0];
            const right = segs[1];
            const bottom = segs[2];
            const left = segs[3];

            const qs: [2]m.Quadrant = .{ m.quadrant(tl.x - x, tl.y - y), m.quadrant(br.x - x, br.y - y) };
            if (qs[0] == qs[1]) {
                switch (qs[0]) {
                    .q_I => {
                        walls.append(left) catch unreachable;
                        walls.append(bottom) catch unreachable;
                    },
                    .q_II => {
                        walls.append(bottom) catch unreachable;
                        walls.append(right) catch unreachable;
                    },
                    .q_III => {
                        walls.append(top) catch unreachable;
                        walls.append(right) catch unreachable;
                    },
                    .q_IV => {
                        walls.append(top) catch unreachable;
                        walls.append(left) catch unreachable;
                    },
                    .none => unreachable,
                }
            } else {
                if (br.x - x < 0) {
                    walls.append(right) catch unreachable;
                } else if (tl.x - x > 0) {
                    walls.append(left) catch unreachable;
                } else if (br.y - y < 0) {
                    walls.append(bottom) catch unreachable;
                } else if (tl.y - y > 0) {
                    walls.append(top) catch unreachable;
                }
            }

            for (walls.items) |*seg| {
                seg.p1.angle = angleTo(seg.p1.x, seg.p1.y, x, y);
                seg.p2.angle = angleTo(seg.p2.x, seg.p2.y, x, y);

                seg.d = (seg.p1.x - x) * (seg.p1.x - x) + (seg.p1.y - y) * (seg.p1.y - y);
                array_list.append(seg.*) catch unreachable;
            }
        }
    }
}

fn findRectsIntersectingSquareAround(
    world: *m.World,
    array_list: *std.ArrayList(m.URect),
    x: f32,
    y: f32,
    range: usize,
) void {
    const r: f32 = @floatFromInt(range);
    for (world.rectangles.items) |rect| {
        if (rectIntersectsPoint(x - r, y - r, x + r, y + r, m.flint(f32, rect.tl.x), m.flint(f32, rect.tl.y)) or
            rectIntersectsPoint(x - r, y - r, x + r, y + r, m.flint(f32, rect.br.x), m.flint(f32, rect.br.y)))
        {
            array_list.append(rect) catch unreachable;
        }
    }
}

fn rectIntersectsPoint(x1: f32, y1: f32, x2: f32, y2: f32, px: f32, py: f32) bool {
    return (x1 <= px and x2 >= px and y1 <= py and y2 >= py);
}

//
// utility functions
//

// https://doc.cgal.org/latest/Visibility_2/index.html

// // Return p*(1-f) + q*f
// static private function interpolate(p:Point, q:Point, f:Float):Point {
//     return new Point(p.x*(1-f) + q.x*f, p.y*(1-f) + q.y*f);
// }

//   // Helper: do we know that segment a is in front of b?
//     // Implementation not anti-symmetric (that is to say,
//     // _segment_in_front_of(a, b) != (!_segment_in_front_of(b, a)).
//     // Also note that it only has to work in a restricted set of cases
//     // in the visibility algorithm; I don't think it handles all
//     // cases. See http://www.redblobgames.com/articles/visibility/segment-sorting.html
//     private function _segment_in_front_of(a:Segment, b:Segment, relativeTo:Point):Bool {
//         // NOTE: we slightly shorten the segments so that
//         // intersections of the endpoints (common) don't count as
//         // intersections in this algorithm
//         var A1 = leftOf(a, interpolate(b.p1, b.p2, 0.01));
//         var A2 = leftOf(a, interpolate(b.p2, b.p1, 0.01));
//         var A3 = leftOf(a, relativeTo);
//         var B1 = leftOf(b, interpolate(a.p1, a.p2, 0.01));
//         var B2 = leftOf(b, interpolate(a.p2, a.p1, 0.01));
//         var B3 = leftOf(b, relativeTo);

//         // NOTE: this algorithm is probably worthy of a short article
//         // but for now, draw it on paper to see how it works. Consider
//         // the line A1-A2. If both B1 and B2 are on one side and
//         // relativeTo is on the other side, then A is in between the
//         // viewer and B. We can do the same with B1-B2: if A1 and A2
//         // are on one side, and relativeTo is on the other side, then
//         // B is in between the viewer and A.
//         if (B1 == B2 && B2 != B3) return true;
//         if (A1 == A2 && A2 == A3) return true;
//         if (A1 == A2 && A2 != A3) return false;
//         if (B1 == B2 && B2 == B3) return false;

//         // If A1 != A2 and B1 != B2 then we have an intersection.
//         // Expose it for the GUI to show a message. A more robust
//         // implementation would split segments at intersections so
//         // that part of the segment is in front and part is behind.
//         demo_intersectionsDetected.push([a.p1, a.p2, b.p1, b.p2]);
//         return false;

//         // NOTE: previous implementation was a.d < b.d. That's simpler
//         // but trouble when the segments are of dissimilar sizes. If
//         // you're on a grid and the segments are similarly sized, then
//         // using distance will be a simpler and faster implementation.
//     // }

fn getWallsFacing(world: *m.World, rects: *std.ArrayList(m.URect), px: f32, py: f32) void {
    // var walls = std.ArrayList(m.Uvec2).init(world.allocator);
    // defer walls.deinit();

    for (rects.items) |rect| {
        const vertices = getRectEdgeVertices(world, rect, px, py);
        var last: ?m.Uvec2 = undefined;
        for (vertices) |maybe_v| {
            if (maybe_v) |v| {
                if (last) |l| {
                    rl.drawLine(
                        m.cast(i32, l.x * CELL_SIZE),
                        m.cast(i32, l.y * CELL_SIZE),
                        m.cast(i32, v.x * CELL_SIZE),
                        m.cast(i32, v.y * CELL_SIZE),
                        rl.Color.init(0, 255, 0, 255),
                    );
                }
                // walls.append(v) catch unreachable;
                last = v;
            }
        }
    }
}

// TODO this should find vertices within range as a bounding box, not a radius.
fn findEdgeVerticesNearPlayer(world: *m.World, arraylist: *std.ArrayList(m.Uvec2), range: usize) void {
    var distances = std.ArrayList(distWithPoint).init(world.allocator);
    defer distances.deinit();

    // const pp = world.player.position.uvec2();

    // TODO pre-cull, cache, or pre-sort proximate rectangles to avoid
    // implausible performance on very large maps.
    // look into spatial hashing / spatial indexing.

    for (world.rectangles.items) |rect| {
        const vertices = getRectEdgeVertices(world, rect, world.player.position.x, world.player.position.y);

        for (vertices) |maybe_v| {
            if (maybe_v) |v| {
                const d = distanceOfUvec2s(world.player.position.uvec2(), v);
                if (d < m.flint(f32, range)) {
                    distances.append(.{ d, v }) catch unreachable;
                }
            }
        }
    }
    std.mem.sort(distWithPoint, distances.items, {}, cmpDistWithPoint);

    for (distances.items) |d| {
        if (d[0] < @as(f32, @floatFromInt(range))) {
            arraylist.append(d[1]) catch unreachable;
            if (true) { // draw debug lines
                drawLineFromPlayerTo(world, d[1].x, d[1].y, 40);

                drawLineToBoundingBox(world, d[1].x, d[1].y, m.cast(i32, range * CELL_SIZE), 40);
            }
        }
    }
}

fn getFacingSegments(world: *m.World, segments: [4]m.WallSegment, px: f32, py: f32) [2]?m.WallSegment {
    _ = world;
    const tl = segments[0].p1;
    const br = segments[1].p2;

    const top = segments[0];
    const bot = segments[2];
    const rgt = segments[1];
    const lft = segments[3];

    const q1 = m.quadrant(tl.x - px, tl.y - py);
    const q2 = m.quadrant(br.x - px, br.y - py);

    if (q1 == q2) { // rect wholly in one quadrant
        return switch (q1) {
            .q_I => .{ lft, bot },
            .q_II => .{ bot, rgt },
            .q_III => .{ top, rgt },
            .q_IV => .{ lft, top },
            .none => unreachable,
        };
    } else { // rect spans two quadrants; is in one of the four cardinal directions
        if (br.x - px < 0) { // left of player
            return .{ rgt, null };
        } else if (tl.x - px > 0) { // right of player
            return .{ lft, null };
        } else if (br.y - py < 0) { // above player
            return .{ bot, null };
        } else if (tl.y - py > 0) { // below player
            return .{ top, null };
        }
    }
    unreachable;
}

fn getRectEdgeVertices(world: *m.World, rect: m.URect, px: f32, py: f32) [3]?m.Uvec2 {
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
            .q_I => .{ tl, bl, br },
            .q_II => .{ bl, br, tr },
            .q_III => .{ tl, tr, br },
            .q_IV => .{ bl, tl, tr },
            .none => unreachable,
        };
    } else { // rect spans two quadrants; is in one of the four cardinal directions
        if (rel_x2 < 0) { // left of player
            return .{ tr, br, null };
        } else if (rel_x > 0) { // right of player
            return .{ tl, bl, null };
        } else if (rel_y2 < 0) { // above player
            return .{ bl, br, null };
        } else if (rel_y > 0) { // below player
            return .{ tl, tr, null };
        }
    }
    _ = .{world};
    unreachable;
}

fn drawLineFromPlayerTo(world: *m.World, x: usize, y: usize, alpha: u8) void {
    const px: i32 = @intFromFloat(world.player.position.x * CELL_SIZE_F);
    const py: i32 = @intFromFloat(world.player.position.y * CELL_SIZE_F);

    const pt = m.Ivec2{
        .x = m.cast(i32, x * CELL_SIZE),
        .y = m.cast(i32, y * CELL_SIZE),
    };
    rl.drawLine(px, py, pt.x, pt.y, rl.Color.init(255, 255, 0, alpha));
}

const half_pi: f32 = std.math.pi / @as(f32, 2.0);

fn drawLineToBoundingBox(world: *m.World, x: usize, y: usize, range: i32, alpha: u8) void {
    const px: f32 = (world.player.position.x) * CELL_SIZE_F;
    const py: f32 = (world.player.position.y) * CELL_SIZE_F;

    const angle: f32 = angleBetweenPoints(px, py, m.flint(f32, x) * CELL_SIZE_F, m.flint(f32, y) * CELL_SIZE_F);

    // brutishly finding the distance to the edge of the range rectangle
    const len1: f32 = @abs(m.flint(f32, range) / std.math.sin(half_pi - angle));
    const len2: f32 = @abs(m.flint(f32, range) / std.math.cos(half_pi - angle));
    const len = @min(len1, len2);

    const tx: f32 = px + std.math.cos(angle) * len;
    const ty: f32 = py + std.math.sin(angle) * len;

    rl.drawLine(
        @intFromFloat(px),
        @intFromFloat(py),
        @intFromFloat(tx),
        @intFromFloat(ty),
        rl.Color.init(0, 255, 255, alpha),
    );
}

fn angleFromPlayerTo(world: *m.World, x: usize, y: usize) f32 {
    return std.math.atan2(
        m.flint(f32, x) - world.player.position.y,
        m.flint(f32, y) - world.player.position.x,
    );
}

fn angleTo(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    return std.math.atan2(y2 - y1, x2 - x1);
}

fn angleBetweenPoints(x1: f32, y1: f32, x2: f32, y2: f32) f32 {
    return std.math.atan2(y2 - y1, x2 - x1);
}

fn distanceOfUvec2s(a: m.Uvec2, b: m.Uvec2) f32 {
    const ax: f32 = @floatFromInt(a.x);
    const ay: f32 = @floatFromInt(a.y);
    const bx: f32 = @floatFromInt(b.x);
    const by: f32 = @floatFromInt(b.y);
    return std.math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
}
