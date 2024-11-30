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
    for (0..100) |_| {
        const w = rng.uintLessThanBiased(usize, 5) + 1;
        const h = rng.uintLessThanBiased(usize, 5) + 1;
        const x = rng.uintLessThanBiased(usize, max.x - w - 1) + 1;
        const y = rng.uintLessThanBiased(usize, max.y - h - 1) + 1;
        for (x..x + w) |wx| {
            for (y..y + h) |wy| {
                // const i = cells.indexOf(wx, wy, 0) catch continue;
                cells.set(wx, wy, 0, t.Cell{ .tile = t.Tile{ .Solid = .Stone } }) catch continue;
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

// https://www.drdobbs.com/database/the-maximal-rectangle-problem/184410529
//
// we want to to generate a list of all rectangles which are not wholly contained within other rectangles

var rects: std.ArrayList(m.URect) = undefined;

// a mostly dumb, brute force approach - but one I understand
// tl,br = top left, bottom right
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
            }
        }
    }
}
