const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

// const input = @import("input.zig");
const vec = @import("vec.zig");
const m = @import("main.zig");
const t = @import("terrain.zig");

const CommandTag = enum {
    move,
    turn,
    attack,
};

const Command = union(enum) { move: Direction, turn: i16, attack: Direction };

pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    pos: vec.Uvec2,
    z: usize,
    facing: f32,
    move: ?Direction = undefined,

    pub fn moveTo(self: *Player, world: *m.World, direction: Direction) MoveCommandError!void {
        const delta = direction.ivec2();

        if (!t.isMoveBoundsValid(self.pos, direction)) {
            self.move = null;
            return MoveCommandError.OutOfBounds;
        }

        const new_pos = vec.Uvec2{
            .x = @intCast(self.pos.x + delta.x),
            .y = @intCast(self.pos.y + delta.y),
        };

        self.move = null;

        if (world.cells.isPassable(self.z, new_pos.y, new_pos.x) catch false) {
            self.pos = new_pos;
        } else {
            return MoveCommandError.ImpassableTerrain;
        }
    }
};

const MoveCommandError = error{
    OutOfBounds,
    ImpassableTerrain,
};

pub fn init(alloc: std.mem.Allocator) !*Player {
    const ptr = try alloc.create(Player);
    ptr.* = .{
        .pos = vec.Uvec2{ .x = 50, .y = 50 },
        .z = 0,
        .facing = 0.0,
    };
    return ptr;
}

pub const Direction = enum {
    North,
    NorthEast,
    East,
    SouthEast,
    South,
    SouthWest,
    West,
    NorthWest,

    pub fn ivec2(self: Direction) vec.Ivec2 {
        return Direction_Vectors[@intFromEnum(self)];
    }
};

pub const Direction_Vectors = [_]vec.Ivec2{
    .{ .x = 0, .y = -1 },
    .{ .x = 1, .y = -1 },
    .{ .x = 1, .y = 0 },
    .{ .x = 1, .y = 1 },
    .{ .x = 0, .y = 1 },
    .{ .x = -1, .y = 1 },
    .{ .x = -1, .y = 0 },
    .{ .x = -1, .y = -1 },
};

pub const CardinalDirections = [_]Direction{
    .North,
    .East,
    .South,
    .West,
};

pub const OrdinalDirections = [_]Direction{
    .NorthWest,
    .NorthEast,
    .SouthEast,
    .SouthWest,
};
