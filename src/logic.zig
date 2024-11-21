const std = @import("std");
const rl = @import("raylib");
const znoise = @import("znoise");
const input = @import("input.zig");
const rng = std.crypto.random;

pub fn init(alloc: std.mem.Allocator) void {
    initMap(alloc);
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
                cells.data[player.z][y][x] = Cell{
                    .tile = Tile{ .Floor = .Stone },
                };
            }
        }
    }
}

pub fn tick(alloc: std.mem.Allocator) void {
    _ = alloc;
    input.handleKeyboard();
    input.handleMouse();
    playerMove() catch {};
    _ = 4;
}

const MoveCommandError = error{
    OutOfBounds,
    ImpassableTerrain,
};

fn playerMove() MoveCommandError!void {
    if (player.move) |direction| {
        const delta = direction.ivec2();
        const pos = player.pos;

        if ((pos.x == 0 and delta.x < 0) or
            (pos.y == 0 and delta.y < 0) or
            (pos.x == CELLS_LEN.x and delta.x > 0) or
            (pos.y == CELLS_LEN.y and delta.y > 0))
        {
            player.move = null;
            return MoveCommandError.OutOfBounds;
        }

        const new_pos = Uvec2{
            .x = @intCast(player.pos.x + delta.x),
            .y = @intCast(player.pos.y + delta.y),
        };

        player.move = null;

        switch (cells.data[player.z][new_pos.y][new_pos.x].tile) {
            .Solid => {
                return MoveCommandError.ImpassableTerrain;
            },
            else => {
                // might want to add some indirection  ..
                player.pos = new_pos;
            },
        }
    }
}

pub fn deinit() void {}

// public data

pub var cells: Cells = Cells{};

pub var player = Player{
    .pos = Uvec2{
        .x = CELLS_LEN.x / 2,
        .y = CELLS_LEN.y / 2,
    },
    .z = 0,
    .facing = 0.0,
};

pub const CardinalDirection = enum {
    North,
    East,
    South,
    West,

    pub fn ivec2(self: CardinalDirection) Ivec2 {
        const i: usize = @intFromEnum(self);
        std.debug.assert(i <= CardinalDirectionIvec2.len);
        return CardinalDirectionIvec2[i];
    }
};

test "cardinal direction" {
    const c = CardinalDirection;
    try std.testing.expectEqual(c.North.ivec2(), Ivec2{ .x = 0, .y = -1 });
    try std.testing.expectEqual(c.South.ivec2(), Ivec2{ .x = 0, .y = 1 });
    try std.testing.expectEqual(c.East.ivec2(), Ivec2{ .x = 1, .y = 0 });
    try std.testing.expectEqual(c.West.ivec2(), Ivec2{ .x = -1, .y = 0 });
}

const CardinalDirectionIvec2 = [_]Ivec2{
    .{ .x = 0, .y = -1 },
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = 1 },
    .{ .x = -1, .y = 0 },
};

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

pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    pos: Uvec2,
    z: usize,
    facing: f32,
    move: ?CardinalDirection = undefined,
};

// private data

const Rect2d = struct {
    origin: Uvec2, // top left
    extent: Uvec2, // bot right
};

pub const Ivec3 = struct { x: i32, y: i32, z: i32 };
pub const Ivec2 = struct { x: i32, y: i32 };

pub const Uvec3 = struct { x: u16, y: u16, z: u16 };
pub const Uvec2 = struct { x: u16, y: u16 };

pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Vec2 = struct { x: f32, y: f32 };

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
const CellMatrixYX = [CELLS_LEN.y][CELLS_LEN.x]Cell;
const CellMatrixZYX = [CELLS_LEN.z][CELLS_LEN.y][CELLS_LEN.x]Cell;

const CELLS_LEN = Uvec3{ .x = 100, .y = 100, .z = 2 };
