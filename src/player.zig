const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

// const input = @import("input.zig");
const vec = @import("vec.zig");
const t = @import("terrain.zig");

// pub var player = Player{
//     .pos = vec.Uvec2{
//         .x = 50,
//         .y = 50,
//     },
//     .z = 0,
//     .facing = 0.0,
// };

// pub const Player = struct {
pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    pos: vec.Uvec2,
    z: usize,
    facing: f32,
    move: ?CardinalDirection = undefined,

    pub fn moveTo(self: *Player, direction: CardinalDirection) MoveCommandError!void {
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

        if (t.isPassable(self.z, new_pos.y, new_pos.x) catch false) {
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

pub const CardinalDirection = enum {
    North,
    East,
    South,
    West,

    pub fn ivec2(self: CardinalDirection) vec.Ivec2 {
        const i: usize = @intFromEnum(self);
        std.debug.assert(i <= CardinalDirectionIvec2.len);
        return CardinalDirectionIvec2[i];
    }
};

test "cardinal direction" {
    const c = CardinalDirection;
    try std.testing.expectEqual(c.North.ivec2(), vec.Ivec2{ .x = 0, .y = -1 });
    try std.testing.expectEqual(c.South.ivec2(), vec.Ivec2{ .x = 0, .y = 1 });
    try std.testing.expectEqual(c.East.ivec2(), vec.Ivec2{ .x = 1, .y = 0 });
    try std.testing.expectEqual(c.West.ivec2(), vec.Ivec2{ .x = -1, .y = 0 });
}

const CardinalDirectionIvec2 = [_]vec.Ivec2{
    .{ .x = 0, .y = -1 },
    .{ .x = 1, .y = 0 },
    .{ .x = 0, .y = 1 },
    .{ .x = -1, .y = 0 },
};
