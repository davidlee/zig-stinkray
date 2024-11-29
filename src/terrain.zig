const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");
const wgen = @import("world_gen.zig");

const WIDTH: usize = 50;
const HEIGHT: usize = 50;
const DEPTH: usize = 2;

pub const CellStoreError = error{
    InvalidCoordinate,
};

pub const RectAddr = struct { cell: Cell, x: usize, y: usize };

pub const CellStore = struct {

    // this should be considered private; prefer access through methods
    _arraylist: std.ArrayList(Cell),
    _width: usize = 0,
    _height: usize = 0,
    _depth: usize = 0,

    // TODO when I'm feeling smart enough, build a custom iterator
    // to avoid leaking internals directly

    fn _initWithSize(self: *CellStore, allocator: std.mem.Allocator, width: usize, height: usize, depth: usize) !void {
        self._width = width;
        self._height = height;
        self._depth = depth;
        self._arraylist = try std.ArrayList(Cell).initCapacity(
            allocator,
            self._width * self._height * self._depth,
        );
    }

    pub fn init(self: *CellStore, allocator: std.mem.Allocator) void {
        self._initWithSize(allocator, WIDTH, HEIGHT, DEPTH) catch unreachable;
    }

    pub fn deinit(self: *CellStore) void {
        self._arraylist.deinit();
    }

    // meh ugly getter/setters, but better than leaking internals
    // could probably use comptime to save a few characters

    pub fn getWidth(self: CellStore) usize {
        return self._width;
    }

    pub fn getHeight(self: CellStore) usize {
        return self._height;
    }

    pub fn getDepth(self: CellStore) usize {
        return self._depth;
    }

    pub fn getLen(self: CellStore) usize {
        return self._arraylist.items.len;
    }

    pub fn getSize(self: CellStore) m.Uvec3 {
        return .{ .x = self._width, .y = self._height, .z = self._depth };
    }

    pub fn _setInitial(self: *CellStore, i: usize, cell: Cell) void {
        self._arraylist.insertAssumeCapacity(i, cell);
    }

    pub fn get(self: CellStore, x: usize, y: usize, z: usize) CellStoreError!Cell {
        const i = try self.indexOf(x, y, z);
        return self._get(i);
    }

    pub fn getByIndex(self: CellStore, i: usize) !Cell {
        return self._get(i);
    }

    fn _get(self: CellStore, i: usize) !Cell {
        if (i >= self._arraylist.items.len) {
            std.log.debug("get {d} out of bounds for {d}", .{ i, self._arraylist.items.len });
            return CellStoreError.InvalidCoordinate;
        }
        return self._arraylist.items[i];
    }

    fn _getUnchecked(self: CellStore, i: usize) Cell {
        return self._arraylist.items[i];
    }

    fn _set(self: *CellStore, i: usize, cell: Cell) void {
        self._arraylist.items[i] = cell;
    }

    fn getByIndexUnchecked(self: CellStore, i: usize) Cell {
        return self._getUnchecked(i);
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
        const cell = self.get(x, y, z) catch unreachable;

        return switch (cell.tile) {
            .Empty => false,
            .Floor => false,
            .Solid => true,
        };
    }

    pub fn xyzOf(self: CellStore, i: usize) !m.Uvec3 {
        const max = self.getSize();
        const x = i % max.x;
        const y = i / max.x;
        const z = i / (max.x * max.y);

        if (x > max.x or y > max.y or z > max.z) {
            return CellStoreError.InvalidCoordinate;
        }
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn indexOf(self: CellStore, x: usize, y: usize, z: usize) !usize {
        const max = self.getSize();

        if (x > max.x or y > max.y or z > max.z) {
            return CellStoreError.InvalidCoordinate;
        }
        return z * (max.x * max.y) + y * max.x + x;
    }

    pub fn isMoveBoundsValid(self: CellStore, pos: m.Uvec2, direction: m.Direction) bool {
        const max = self.getSize();
        const delta = direction.ivec2();

        if ((pos.x == 0 and delta.x < 0) or
            (pos.y == 0 and delta.y < 0) or
            (pos.x == max.x and delta.x > 0) or
            (pos.y == max.y and delta.y > 0))
        {
            return false;
        } else {
            return true;
        }
    }

    // get a rectangle of cells at z, centered on x,y
    // and append to an array list
    // useful for drawing
    pub fn getRect(
        self: CellStore,
        al: *std.ArrayList(RectAddr),
        x: usize,
        y: usize,
        z: usize,
        width: usize,
        height: usize,
    ) !void {
        const max_len = self._arraylist.items.len;
        const max = self.getSize();
        try al.ensureTotalCapacity(width * height);

        const x0: usize = x -| width / 2;
        const y0: usize = y -| height / 2;
        const start_index: usize = try self.indexOf(x0, y0, z);
        var row: usize = 0;
        while (row < height and (y0 + row) <= max.y) : (row += 1) {
            const dy = y0 + row;
            const vert_index_offset = row * max.x;
            var col: usize = 0;
            while (col < width and (x0 + col) < max.x) : (col += 1) {
                const dx = x0 + col;
                const i = start_index + vert_index_offset + col;
                const c = self._get(i) catch null;
                if (c) |cell| {
                    al.appendAssumeCapacity(RectAddr{
                        .x = dx,
                        .y = dy,
                        .cell = cell,
                    });
                } else {
                    std.log.debug("** getRect {d} out of bounds for {d}", .{ i, max_len });
                }
            }
        }
    }
};

// only needs to be a function because the casting is a pain in the ass
pub fn relativePos(to: m.Uvec2, x: usize, y: usize) !m.Ivec2 {
    const px = m.cast(i32, x) - m.cast(i32, to.x);
    const py = m.cast(i32, y) - m.cast(i32, to.y);
    return .{ .x = px, .y = py };
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
