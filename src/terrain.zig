const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

const input = @import("input.zig");
const vec = @import("vec.zig");

pub var cells: Cells = Cells{};

pub const Tile = union(TileTag) {
    Empty,
    Floor: CellMaterial,
    Solid: CellMaterial,
};

pub const Cell = struct {
    tile: Tile = .Empty,
    items: u8 = 0,
};

pub const Cells = struct {
    data: CellMatrixZYX = @splat(@splat(@splat(Cell{}))),
};

// private data

const CellMaterial = enum {
    Wood,
    Stone,
    Dirt,
    Rock,
    Iron,
    Mud,
};

const TileTag = enum {
    Empty,
    Floor,
    Solid,
};

const CellMatrixYX = [MAX.y][MAX.x]Cell;
const CellMatrixZYX = [MAX.z][MAX.y][MAX.x]Cell;

// TODO avoid making this public
pub const MAX = vec.Uvec3{ .x = 100, .y = 100, .z = 2 };

const Rect2d = struct {
    origin: vec.Uvec2, // top left
    extent: vec.Uvec2, // bot right
};

pub fn init(alloc: std.mem.Allocator) void {
    initMap(alloc);
}

pub fn getCellAtZYX(z: usize, y: usize, x: usize) *Cell {
    std.debug.assert(z <= MAX.z);
    std.debug.assert(y <= MAX.y);
    std.debug.assert(x <= MAX.x);
    return &cells.data[z][y][x];
}

pub fn setCellAtZYX(z: usize, y: usize, x: usize, cell: Cell) void {
    std.debug.assert(z <= MAX.z);
    std.debug.assert(y <= MAX.y);
    std.debug.assert(x <= MAX.x);
    cells.data[z][y][x] = cell;
}

// would be nice for magic vec to support this
// pub fn applyDeltaToPosition(pos: vec.Uvec3, delta: vec.Ivec3) !vec.Uvec3 {
// }

// pub fn validMove(pos: vec.Uvec3, delta: vec.Ivec3) !bool {
//     std.debug.assert(pos.z <= MAX.z);
//     std.debug.assert(pos.y <= MAX.y);
//     std.debug.assert(pos.x <= MAX.x);
// }

pub fn isPassable(z: usize, y: usize, x: usize) !bool {
    return switch (getCellAtZYX(z, y, x).tile) {
        .Empty => true,
        .Floor => true,
        .Solid => false,
    };
}

fn initMap(alloc: std.mem.Allocator) void {
    _ = alloc;

    genTerrainNoise();
    genRooms();
}

fn genTerrainNoise() void {
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    const k = 0.35;

    for (cells.data, 0..) |zs, z| {
        std.debug.print("yes, ", .{});
        for (zs, 0..) |ys, y| {
            for (ys, 0..) |_, x| {
                const noiseX: f32 = @floatFromInt(x);
                const noiseY: f32 = @floatFromInt(y);

                if (gen.noise2(noiseX, noiseY) > k) {
                    cells.data[z][y][x] = Cell{ .tile = Tile{ .Solid = .Stone } };
                } else {
                    cells.data[z][y][x] = Cell{ .tile = Tile{ .Floor = .Dirt } };
                }
            }
        }
    }
}

// TODO do we care to keep metadata about rooms after build?
// connect rooms with passageways
// choose a room & location for some things like
// entry & exit location
// treasure, places of interest
fn genRooms() void {
    var rooms: [16]Rect2d = undefined; // avoid allocation
    for (rooms, 0..) |_, i| {
        const origin = vec.Uvec2{
            .x = rng.uintLessThanBiased(u16, 80),
            .y = rng.uintLessThanBiased(u16, 80),
        };
        const room = Rect2d{
            .origin = origin,
            .extent = vec.Uvec2{
                .x = origin.x + rng.uintLessThanBiased(u16, 20),
                .y = origin.y + rng.uintLessThanBiased(u16, 12),
            },
        };
        rooms[i] = room;

        // excavate rooms
        for (room.origin.y..room.extent.y) |y| {
            for (room.origin.x..room.extent.x) |x| {
                // FIXME only first floor for now
                cells.data[0][y][x] = Cell{
                    .tile = Tile{ .Floor = .Stone },
                };
            }
        }
    }
}
