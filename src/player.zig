const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

// const input = @import("input.zig");
const m = @import("main.zig");
const t = @import("terrain.zig");

const CommandTag = enum {
    move,
    turn,
    attack,
};

const Command = union(enum) {
    move: m.Direction,
    turn: m.RotationalDirection,
    attack: m.Direction,
};

pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    pos: m.Uvec2,
    z: usize,
    facing: u8,
    // command: ?Command,

    pub fn moveTo(self: Player, world: *m.World, direction: m.Direction) MoveCommandError!void {
        const delta = direction.ivec2();

        if (!t.isMoveBoundsValid(self.pos, direction)) {
            return MoveCommandError.OutOfBounds;
        }

        const new_pos = m.Uvec2{
            .x = m.addSignedtoUsize(self.pos.x, delta.x),
            .y = m.addSignedtoUsize(self.pos.y, delta.y),
        };

        if (world.cells.isPassable(new_pos.x, new_pos.y, self.z) catch false) {
            world.player.pos = new_pos;
        } else {
            return MoveCommandError.ImpassableTerrain;
        }
    }
};

const MoveCommandError = error{
    OutOfBounds,
    ImpassableTerrain,
};

pub fn init(world: *m.World) void {
    world.player = Player{
        .pos = m.Uvec2{ .x = 50, .y = 50 },
        .inventory = .{},
        .z = 0,
        .facing = 0.0,
    };
}
