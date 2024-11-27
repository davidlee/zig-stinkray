const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");
const wgen = @import("world_gen.zig");

pub const MAX = m.Uvec3{ .x = 200, .y = 200, .z = 2 };
pub const LEN: usize = @as(usize, MAX.x) * @as(usize, MAX.y) * @as(usize, MAX.z);

pub const CellStoreError = error{
    InvalidCoordinate,
};

pub const RectAddr = struct { cell: Cell, x: usize, y: usize };

pub const CellStore = struct {

    // this should be considered private; prefer access through methods
    _arraylist: std.ArrayList(Cell),

    // TODO when I'm feeling smart enough, build a custom iterator
    // to avoid leaking internals directly

    fn _get(self: CellStore, i: usize) Cell {
        return self._arraylist.items[i];
    }

    fn _set(self: *CellStore, i: usize, cell: Cell) void {
        self._arraylist.items[i] = cell;
    }

    pub fn _setInitial(self: *CellStore, i: usize, cell: Cell) void {
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

    // gets a rectangle of cells centered on x,y
    // and appends them to al
    pub fn getRect(
        self: CellStore,
        al: *std.ArrayList(RectAddr),
        x: usize,
        y: usize,
        z: usize,
        width: usize,
        height: usize,
    ) !void {
        try al.ensureTotalCapacity(width * height);
        const x0: usize = x -| width / 2;
        const y0: usize = y -| height / 2;
        const start_index: usize = try self.indexOf(x0, y0, z);
        var row: usize = 0;
        while (row < height) : (row += 1) {
            const dy = y0 + row;
            const vert_index_offset = row * MAX.x;
            var col: usize = 0;
            while (col < width) : (col += 1) {
                const dx = x0 + col;
                const i = start_index + vert_index_offset + col;
                al.appendAssumeCapacity(RectAddr{
                    .x = dx,
                    .y = dy,
                    .cell = self._get(i),
                });
            }
        }
    }

    pub fn xyzOf(self: CellStore, i: usize) !m.Uvec3 {
        _ = self;
        const x = i % MAX.x;
        const y = i / MAX.x;
        const z = i / (MAX.x * MAX.y);

        if (x > MAX.x or y > MAX.y or z > MAX.z) {
            return CellStoreError.InvalidCoordinate;
        }
        return .{ .x = x, .y = y, .z = z };
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

pub fn relativePos(to: m.Uvec2, x: usize, y: usize) !m.Ivec2 {
    const px = m.cast(i32, to.x) - m.cast(i32, x);
    const py = m.cast(i32, to.y) - m.cast(i32, y);
    return .{ .x = px, .y = py };
}

pub fn getRectOrigin(center: m.Uvec2, width: usize, height: usize) m.Uvec2 {
    const x = center.x -| width / 2;
    const y = center.y -| height / 2;
    return .{ .x = x, .y = y };
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

//
// constants
//

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
