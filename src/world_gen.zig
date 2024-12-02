const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");
const t = @import("terrain.zig");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");

pub fn init(world: *m.World) void {
    initMap(world);
}

fn initMap(world: *m.World) void {
    zeroMap(&world.cells);
    genRectObstacles(&world.cells);
    identifyBlockingRectangles(world);
    positionPlayer(world);
}

fn positionPlayer(world: *m.World) void {
    const max = world.cells.getSize();
    while (true) {
        const x = rng.uintLessThanBiased(usize, max.x - 1);
        const y = rng.uintLessThanBiased(usize, max.y - 1);
        if (world.cells.isPassable(x, y, 0) catch false) {
            world.player.position = m.Vec3{
                .x = m.flint(f32, x),
                .y = m.flint(f32, y),
                .z = 0,
            };
            break;
        }
    }
}

// let's intentionally forget everything we know about rooms here
// so we have to implement a terrible algorithm later.
//
fn genRectObstacles(cells: *t.CellStore) void {
    const max = cells.getSize();
    const count: usize = @intFromFloat(std.math.sqrt(m.flint(f32, max.x * max.y / 4)));
    for (0..count) |_| {
        const w = rng.uintLessThanBiased(usize, 5) + 1;
        const h = rng.uintLessThanBiased(usize, 5) + 1;
        const x = rng.uintLessThanBiased(usize, max.x - w - 1) + 1;
        const y = rng.uintLessThanBiased(usize, max.y - h - 1) + 1;
        for (x..x + w) |wx| {
            for (y..y + h) |wy| {
                // const i = cells.indexOf(wx, wy, 0) catch continue;
                cells.set(wx, wy, 0, t.Cell{ .tile = t.Tile{ .Solid = .Stone } }) catch unreachable;
            }
        }
    }
}

fn zeroMap(cells: *t.CellStore) void {
    for (0..cells._arraylist.capacity) |i| {
        cells._setInitial(i, t.Cell{ .tile = t.Tile{ .Floor = .Dirt } });
    }
}

fn genTerrainNoise(cells: *t.CellStore) !void {
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    const k = 0.35;

    for (0..(cells._arraylist.capacity + 1)) |i| {
        const xy = try cells.xyzOf(i);

        const noiseX: f32 = @floatFromInt(xy.x);
        const noiseY: f32 = @floatFromInt(xy.y);

        if (gen.noise2(noiseX, noiseY) > k) {
            const cell = t.Cell{ .tile = t.Tile{ .Solid = .Stone } };
            cells._setInitial(i, cell);
        } else {
            const cell = t.Cell{ .tile = t.Tile{ .Floor = .Dirt } };
            cells._setInitial(i, cell);
        }
    }
}

var rects: std.ArrayList(m.URect) = undefined;

// generate a list of all rectangles which are not wholly contained within other rectangles
// a mostly dumb, brute force approach - but one I understand
//
// see https://www.drdobbs.com/database/the-maximal-rectangle-problem/184410529
// for more sophisticated approaches

pub fn identifyBlockingRectangles(world: *m.World) void {
    const max = world.cells.getSize();
    for (0..max.y) |y| {
        var x: usize = 0;
        right: while (x < max.x) : (x += 1) {
            const tl = m.Uvec2{ .x = x, .y = y };

            // skip if top left is contained in a known rectangle
            for (world.rectangles.items) |rect| {
                if (rect.containsPoint(tl)) {
                    // but only if we would not skip over a blocking rect (corner case!)
                    if (!world.cells.isBlockingFov(rect.br.x, y, 0)) {
                        x = rect.br.x;
                        continue :right;
                    }
                }
            }

            if (world.cells.isBlockingFov(x, y, 0)) {
                // start a rectangle
                var br = m.Uvec2{ .x = x, .y = y };
                // fill right
                while (br.x < max.x and world.cells.isBlockingFov(br.x, y, 0)) {
                    br.x += 1;
                }

                // fill down, while all rows are blocking
                descend: while (br.y < max.y) : (br.y += 1) {
                    var cx = tl.x; // current row x
                    while (cx < br.x) : (cx += 1) {
                        if (!world.cells.isBlockingFov(cx, br.y, 0)) {
                            break :descend;
                        }
                    }
                }

                const rect = m.URect{ .tl = tl, .br = br };
                world.rectangles.append(rect) catch unreachable;

                const x1 = m.flint(f32, tl.x);
                const y1 = m.flint(f32, tl.y);
                const x2 = m.flint(f32, br.x);
                const y2 = m.flint(f32, br.y);

                addSegment(world, x1, y1, x2, y1, true);
                addSegment(world, x2, y1, x2, y2, false);
                addSegment(world, x2, y2, x1, y2, false);
                addSegment(world, x1, y2, x1, y1, false);
            }
        }
    }
}

fn addSegment(world: *m.World, x1: f32, y1: f32, x2: f32, y2: f32, top_left: bool) void {
    var n1 = world.allocator.create(m.World.EndpointList.Node) catch unreachable;
    var n2 = world.allocator.create(m.World.EndpointList.Node) catch unreachable;
    n1.data.x = x1;
    n1.data.y = y1;
    n1.data.top_left = top_left;
    n2.data.x = x2;
    n2.data.y = y2;
    n2.data.top_left = false;
    world.endpoints.append(n1);
    world.endpoints.append(n2);

    const segment = m.WallSegment{
        .p1 = &n1.data,
        .p2 = &n2.data,
    };
    world.wall_segments.append(segment) catch unreachable;
}

// TODO
// may need to split these into smaller segments
fn loadEdgeSegments() void {}
