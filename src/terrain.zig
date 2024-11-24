const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");

pub const CellStore = struct {
    list: [LEN]Cell,

    pub fn getCellByXYZ(self: CellStore, x: usize, y: usize, z: usize) Cell {
        // std.debug.assert(z <= MAX.z);
        // std.debug.assert(y <= MAX.y);
        // std.debug.assert(x <= MAX.x);
        const i = self.indexFromXYZ(x, y, z);
        return self.list[i];
    }

    pub fn getCellByIndex(self: CellStore, i: usize) Cell {
        return self.list[i];
    }

    pub fn isPassable(self: CellStore, x: usize, y: usize, z: usize) !bool {
        return switch (self.getCellByXYZ(x, y, z).tile) {
            .Empty => true,
            .Floor => true,
            .Solid => false,
        };
    }

    // TODO getVisibleRange()
    //
    const Z_SLICE_SIZE = MAX.x * MAX.y;

    pub fn getRangeAtZ(self: CellStore, z: usize) [Z_SLICE_SIZE]usize {
        _ = self;
        const a = z * Z_SLICE_SIZE;
        var range = [_]usize{0} ** Z_SLICE_SIZE;
        for (0..Z_SLICE_SIZE) |i| {
            range[i] = a + i;
        }
        return range;
    }

    pub fn indexToXYZ(self: CellStore, i: usize) [3]usize {
        _ = self;
        const x = i % MAX.x;
        const y = i / MAX.x;
        const z = i / (MAX.x * MAX.y);
        return .{ x, y, z };
    }

    pub fn indexFromXYZ(self: CellStore, x: usize, y: usize, z: usize) usize {
        _ = self;
        // std.debug.assert(z <= MAX.z);
        // std.debug.assert(y <= MAX.y);
        // std.debug.assert(x <= MAX.x);
        return z * (MAX.x * MAX.y) + y * MAX.x + x;
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

const MAX = m.Uvec3{ .x = 100, .y = 100, .z = 1 };
const LEN: u32 = @as(u32, MAX.x) * @as(u32, MAX.y) * @as(u32, MAX.z);

const Rect2d = struct {
    origin: m.Uvec2, // top left
    extent: m.Uvec2, // bot right
};

pub fn init(alloc: std.mem.Allocator) !*CellStore {
    const cs = try alloc.create(CellStore);
    initMap(cs);
    return cs;
}

pub fn deinit(cells: *CellStore) void {
    defer cells.list.deinit();
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

    for (cells.list, 0..) |_, i| {
        const xy = cells.indexToXYZ(i);

        const noiseX: f32 = @floatFromInt(xy[0]);
        const noiseY: f32 = @floatFromInt(xy[1]);

        if (gen.noise2(noiseX, noiseY) > k) {
            std.debug.print("defo have a solid one", .{});
            const cell = Cell{ .tile = Tile{ .Solid = .Stone } };
            cells.list[i] = cell;
        } else {
            const cell = Cell{ .tile = Tile{ .Floor = .Dirt } };
            cells.list[i] = cell;
        }
    }
}

pub fn isMoveBoundsValid(pos: m.Uvec2, direction: m.Direction) bool {
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
    _ = cells;

    // var rooms: [16]Rect2d = undefined; // avoid allocation
    // for (rooms, 0..) |_, i| {
    //     const origin = m.Uvec2{
    //         .x = rng.uintLessThanBiased(u16, 80),
    //         .y = rng.uintLessThanBiased(u16, 80),
    //     };
    //     const room = Rect2d{
    //         .origin = origin,
    //         .extent = m.Uvec2{
    //             .x = origin.x + rng.uintLessThanBiased(u16, 20),
    //             .y = origin.y + rng.uintLessThanBiased(u16, 12),
    //         },
    //     };
    //     rooms[i] = room;

    //     // excavate rooms
    //     for (room.origin.y..room.extent.y) |y| {
    //         for (room.origin.x..room.extent.x) |x| {
    //             // FIXME only first floor for now
    //             cells.data[0][y][x] = Cell{
    //                 .tile = Tile{ .Floor = .Stone },
    //             };
    //         }
    //     }
    // }

}
