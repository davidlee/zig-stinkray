const std = @import("std");
const rl = @import("raylib");
const znoise = @import("znoise");
const rng = std.crypto.random;

pub var cells: Cells = Cells{};

pub fn init(alloc: std.mem.Allocator) void {
    _ = alloc;

    // start with some noise
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    for (cells.data, 0..) |zs, z| {
        for (zs, 0..) |ys, y| {
            for (ys, 0..) |_, x| {
                const v: f32 = gen.noise2(@floatFromInt(x), @floatFromInt(y));
                if (v < 0.35) {
                    cells.data[z][y][x] = Cell{ .tile = Tile{ .Solid = .Stone } };
                } else {
                    cells.data[z][y][x] = Cell{ .tile = Tile{ .Floor = .Dirt } };
                }
            }
        }
    }

    // then add some rooms
    var rooms: [16]Rect2d = undefined;
    for (rooms, 0..) |_, i| {
        const origin = Uvec2{
            .x = rng.uintLessThanBiased(u16, 80),
            .y = rng.uintLessThanBiased(u16, 80),
        };
        const room = Rect2d{
            .origin = origin,
            .extent = Uvec2{
                .x = origin.x + rng.uintLessThanBiased(u16, 20),
                .y = origin.y + rng.uintLessThanBiased(u16, 12),
            },
        };
        rooms[i] = room;

        // excavate rooms
        for (room.origin.y..room.extent.y) |y| {
            for (room.origin.x..room.extent.x) |x| {
                cells.data[0][@intCast(y)][@intCast(x)] = Cell{ .tile = Tile{ .Floor = .Stone } }; // hardcoded Z=0
            }
        }
    }

    // connect rooms with passageways

    // choose a room & location for some things like
    // entry & exit location
    // treasure, places of interest

}

const Rect2d = struct {
    origin: Uvec2, // top left
    extent: Uvec2, // bot right
};

pub fn tick(alloc: std.mem.Allocator) void {
    _ = alloc;
    return;
}

pub fn deinit() void {}

const Ivec3 = struct { x: i32, y: i32, z: i32 };
const Ivec2 = struct { x: i32, y: i32 };

const Uvec3 = struct { x: u16, y: u16, z: u16 };
const Uvec2 = struct { x: u16, y: u16 };

const Vec3 = struct { x: f32, y: f32, z: f32 };
const Vec2 = struct { x: f32, y: f32 };

const Pos = struct { vec: Vec3, facing: f32 = 0 };

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

const Tile = union(TileTag) {
    Empty,
    Floor: CellMaterial,
    Solid: CellMaterial,
};

const Cell = struct {
    tile: Tile = .Empty,
    items: u8 = 0,
};

const CellMatrixYX = [CELLS_LEN.y][CELLS_LEN.x]Cell;
const CellMatrixZYX = [CELLS_LEN.z][CELLS_LEN.y][CELLS_LEN.x]Cell;

pub const Cells = struct {
    data: CellMatrixZYX = @splat(@splat(@splat(Cell{}))),
};

const CELLS_LEN = Ivec3{ .x = 100, .y = 100, .z = 2 };

const Player = struct {
    health: 10,
    inventory: .{},
    pos: Pos,
};
