const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");

const MAX = m.Uvec3{ .x = 100, .y = 100, .z = 2 };
pub const LEN: usize = @as(usize, MAX.x) * @as(usize, MAX.y) * @as(usize, MAX.z);

pub const CellStoreError = error{
    InvalidCoordinate,
};

pub const CellStore = struct {
    // this should be considered private; prefer access through methods
    // _list: [LEN]Cell,
    _arraylist: std.ArrayList(Cell),

    // TODO when I'm feeling smart enough, build a custom iterator
    // to avoid leaking internals directly

    fn _get(self: CellStore, i: usize) Cell {
        return self._arraylist.items[i];
    }

    fn _set(self: *CellStore, i: usize, cell: Cell) void {
        self._arraylist.items[i] = cell;
    }

    fn _setInitial(self: *CellStore, i: usize, cell: Cell) void {
        self._arraylist.insertAssumeCapacity(i, cell);
    }

    pub fn get(self: CellStore, x: usize, y: usize, z: usize) CellStoreError!Cell {
        const i = try self.indexOf(x, y, z);
        return self._get(i);
    }

    // WARN UNCHECKED
    pub fn getByIndex(self: CellStore, i: usize) Cell {
        return self._get(i);
    }

    pub fn set(self: *CellStore, x: usize, y: usize, z: usize, cell: Cell) CellStoreError!void {
        const i = try self.indexOf(x, y, z);
        self._set(i, cell);
    }

    pub fn isPassable(self: CellStore, x: usize, y: usize, z: usize) CellStoreError!bool {
        const cell = try self.get(x, y, z);

        return switch (cell.tile) {
            .Empty => true,
            .Floor => true,
            .Solid => false,
        };
    }

    pub fn isBlockingFov(self: CellStore, x: usize, y: usize, z: usize) bool {
        _ = .{ self, x, y, z };
        return false;
    }

    // an optimisation to prevent rendering many cells
    // return (a slice?) all potentially visible cells at a given Z, around a given X,Y
    // with given width & height.
    // FIXME
    // TODO
    // pub fn getVisible(self: CellStore, x: usize, y: usize, z: usize, width: usize, height: usize) ![]const Cell {
    //     const w = std.math.clamp(width, 0, MAX.x);
    //     const h = std.math.clamp(height, 0, MAX.y);
    //     const ax = x -| w / 2;
    //     const ay = y -| h / 2;
    //     const bx = std.math.clamp(x +| w / 2, 0, MAX.x);
    //     const by = std.math.clamp(y +| h / 2, 0, MAX.y);
    //     const start_idx = try self.indexOf(ax, ay, z);
    //     const end_idx = try self.indexOf(bx, by, z);

    //     return self._list[start_idx..end_idx];
    // }

    pub fn XYZof(self: CellStore, i: usize) ![3]usize {
        _ = self;

        const x = i % MAX.x;
        const y = i / MAX.x;
        const z = i / (MAX.x * MAX.y);

        if (x > MAX.x or y > MAX.y or z > MAX.z) {
            return CellStoreError.InvalidCoordinate;
        }
        return .{ x, y, z };
    }

    pub fn indexOf(self: CellStore, x: usize, y: usize, z: usize) !usize {
        _ = self;

        if (x > MAX.x or y > MAX.y or z > MAX.z) {
            return CellStoreError.InvalidCoordinate;
        }
        return z * (MAX.x * MAX.y) + y * MAX.x + x;
    }

    pub fn toggleCellPassable(self: *CellStore, x: usize, y: usize, z: usize) !void {
        const cell = try self.get(x, y, z);

        const tile = switch (cell.tile) {
            .Empty => Tile{ .Solid = .Stone },
            .Floor => Tile{ .Solid = .Stone },
            .Solid => Tile{ .Floor = .Dirt },
        };
        const new_cell = Cell{ .tile = tile };
        try self.set(x, y, z, new_cell);
    }

    // stash xy coords in world.region, to draw
    pub fn findBlockingCellsAround(self: *CellStore, x: usize, y: usize, z: usize, radius: usize, array_list: *std.ArrayList(m.Uvec2)) !void {
        for (x -| radius..x + radius) |cx| {
            for (y -| radius..y + radius) |cy| {
                if (!(self.isPassable(cx, cy, z) catch false)) {
                    try array_list.append(m.Uvec2{ .x = cx, .y = cy });
                }
            }
        }
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

pub fn init(world: *m.World) void {
    initMap(world);
}

fn initMap(world: *m.World) void {
    genTerrainNoise(&world.cells) catch std.log.debug("ERR: genTerrainNoise", .{});
    genRooms(world) catch std.log.debug("ERR: getRooms", .{});
}

fn genTerrainNoise(cells: *CellStore) !void {
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    const k = 0.35;

    for (0..LEN) |i| {
        const xy = try cells.XYZof(i);

        const noiseX: f32 = @floatFromInt(xy[0]);
        const noiseY: f32 = @floatFromInt(xy[1]);

        if (gen.noise2(noiseX, noiseY) > k) {
            const cell = Cell{ .tile = Tile{ .Solid = .Stone } };
            cells._setInitial(i, cell);
        } else {
            const cell = Cell{ .tile = Tile{ .Floor = .Dirt } };
            cells._setInitial(i, cell);
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

// TODO keep metadata about rooms after build
// connect rooms with passageways
// choose a room & location for some things like entry & exit location
// add treasure, places of interest
// FIXME handle all Z indexes
// TEST check off by one errors
const Room = struct { x: usize, y: usize, width: usize, height: usize };

const ROOM_SIZE = .{ .min = 4, .max = 30 };
const ROOM_COUNT = .{ .min = 4, .max = 20 };

fn genRooms(world: *m.World) !void {
    const count = rng.uintLessThanBiased(u16, ROOM_COUNT.max - ROOM_COUNT.min) + ROOM_COUNT.min;
    const size_range = ROOM_SIZE.max - ROOM_SIZE.min;
    const z = 0; // FIXME

    var rooms: [ROOM_COUNT.max]Room = undefined;

    for (0..count) |i| {
        const size = .{
            .width = rng.uintLessThanBiased(usize, size_range) + ROOM_COUNT.min,
            .height = rng.uintLessThanBiased(usize, size_range) + ROOM_COUNT.min,
        };

        // allow for a 1 cell border
        const origin_max = .{
            .x = MAX.x - size.width - 2,
            .y = MAX.y - size.height - 2,
        };

        // account for room size in placement
        const origin = m.Uvec2{
            .x = rng.uintLessThanBiased(usize, origin_max.x) + 1,
            .y = rng.uintLessThanBiased(usize, origin_max.y) + 1,
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
                const cell = Cell{ .tile = Tile{ .Floor = .Iron } };
                try world.cells.set(x, y, z, cell);
            }
        }

        rooms[i] = room;
    }

    // TODO
    // draw corridoors, doors, etc
    // store room definitions / metadata -> treasure tables, etc
    // non-rectangular rooms & overlap:
    //   generate rect. rooms as above
    //   check for collisions
    //   randomly union / subtract / reject collisions
    //   will need to describe rooms in metadata using an array or bitmask ..
}
