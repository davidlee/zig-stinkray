const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

const input = @import("input.zig");
const player = @import("player.zig");
const vec = @import("vec.zig");

// pub var cells: Cells = Cells{};

pub const CellStore = struct {
    data: CellMatrixZYX = @splat(@splat(@splat(Cell{}))),

    pub fn getCellAtZYX(self: CellStore, z: usize, y: usize, x: usize) Cell {
        std.debug.assert(z <= MAX.z);
        std.debug.assert(y <= MAX.y);
        std.debug.assert(x <= MAX.x);
        return self.data[z][y][x];
    }

    fn setCellAtZYX(self: CellStore, z: usize, y: usize, x: usize, cell: Cell) void {
        std.debug.assert(z <= MAX.z);
        std.debug.assert(y <= MAX.y);
        std.debug.assert(x <= MAX.x);
        self.data[z][y][x] = cell;
    }

    pub fn isPassable(self: CellStore, z: usize, y: usize, x: usize) !bool {
        return switch (self.getCellAtZYX(z, y, x).tile) {
            .Empty => true,
            .Floor => true,
            .Solid => false,
        };
    }
};

pub const Tile = union(TileTag) {
    Empty,
    Floor: CellMaterial,
    Solid: CellMaterial,
};

pub const Cell = struct {
    tile: Tile = .Empty,
    // items: u8 = 0,
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

// TODO replace with a 1d dynamic array
const CellMatrixYX = [MAX.y][MAX.x]Cell;
const CellMatrixZYX = [MAX.z][MAX.y][MAX.x]Cell;

const MAX = vec.Uvec3{ .x = 100, .y = 100, .z = 2 };

const Rect2d = struct {
    origin: vec.Uvec2, // top left
    extent: vec.Uvec2, // bot right
};

pub fn init(alloc: std.mem.Allocator) !*CellStore {
    const cs = try alloc.create(CellStore);
    initMap(cs);
    return cs;
}

fn initMap(cells: *CellStore) void {
    genTerrainNoise(cells);
    genRooms(cells);
}

fn genTerrainNoise(cells: *CellStore) void {
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    const k = 0.35;

    for (cells.data, 0..) |zs, z| {
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

pub fn isMoveBoundsValid(pos: vec.Uvec2, direction: player.Direction) bool {
    const delta = direction.ivec2();

    if ((pos.x == 0 and delta.x < 0) or
        (pos.y == 0 and delta.y < 0) or
        (pos.x == MAX.x - 1 and delta.x > 0) or
        (pos.y == MAX.y - 1 and delta.y > 0))
    {
        return false;
    } else {
        return true;
    }
}
// TODO do we care to keep metadata about rooms after build?
// connect rooms with passageways
// choose a room & location for some things like
// entry & exit location
// treasure, places of interest
fn genRooms(cells: *CellStore) void {
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
