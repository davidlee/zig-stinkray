const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

// const input = @import("input.zig");
const m = @import("main.zig");
const t = @import("terrain.zig");

// const CommandTag = enum {
//     move,
//     turn,
//     attack,
// };

// const Command = union(enum) {
//     move: Direction,
//     turn: i16,
//     attack: Direction,
// };

pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    pos: m.Uvec2,
    z: usize,
    facing: f32,
    // command: ?Command,

    pub fn moveTo(self: *Player, world: *m.World, direction: m.Direction) MoveCommandError!void {
        const delta = direction.ivec2();

        if (!t.isMoveBoundsValid(self.pos, direction)) {
            return MoveCommandError.OutOfBounds;
        }

        const new_pos = m.Uvec2{
            .x = @intCast(self.pos.x + delta.x),
            .y = @intCast(self.pos.y + delta.y),
        };

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
        .pos = m.Uvec2{ .x = 50, .y = 50 },
        .z = 0,
        .facing = 0.0,
    };
    return ptr;
}
