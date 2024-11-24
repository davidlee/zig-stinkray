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

    // pub fn atXYZ(self: CellStore, x: usize, y: usize, z: usize) Cell {
    //     const i = self.indexFromXYZ(x, y, z);
    //     return self.list[i];
    // }

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

pub fn init(world: *m.World) void {
    initMap(world);
}

pub fn deinit(cells: *CellStore) void {
    defer cells.list.deinit();
}

fn initMap(world: *m.World) void {
    genTerrainNoise(&world.cells);
    genRooms(world);
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

// FIXME all Z indexes
// TEST check off by one errors
const Room = struct { x: u16, y: u16, width: u16, height: u16 };

const ROOM_SIZE = .{ .min = 4, .max = 30 };
const ROOM_COUNT = .{ .min = 4, .max = 20 };

fn genRooms(world: *m.World) void {
    const count = rng.uintLessThanBiased(u16, ROOM_COUNT.max - ROOM_COUNT.min) + ROOM_COUNT.min;
    const size_range = ROOM_SIZE.max - ROOM_SIZE.min;
    const z = 0; // FIXME

    var rooms: [ROOM_COUNT.max]Room = undefined;

    for (0..count) |i| {
        const size = .{
            .width = rng.uintLessThanBiased(u16, size_range) + ROOM_COUNT.min,
            .height = rng.uintLessThanBiased(u16, size_range) + ROOM_COUNT.min,
        };

        // allow for a 1 cell border
        const origin_max = .{
            .x = MAX.x - size.width - 2,
            .y = MAX.y - size.height - 2,
        };

        // account for room size in placement
        const origin = m.Uvec2{
            .x = rng.uintLessThanBiased(u16, origin_max.x) + 1,
            .y = rng.uintLessThanBiased(u16, origin_max.y) + 1,
        };

        const room = Room{
            .x = origin.x,
            .y = origin.y,
            .width = size.width,
            .height = size.height,
        };

        // excavate rooms
        for (room.x..room.x + room.width) |x| {
            for (room.y..room.y + room.height) |y| {
                // var cell = world.cells.getCellByXYZ(x, y, z);
                const j = world.cells.indexFromXYZ(x, y, z);
                world.cells.list[j] = Cell{ .tile = Tile{ .Floor = .Iron } };
                // cell.tile = Tile{ .Floor = .Iron };
            }
        }

        rooms[i] = room;
    }
    // TODO draw corridoors, doors, etc

    // TODO store room definitions / metadata -> treasure tables, etc
}
