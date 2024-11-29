const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

// const input = @import("input.zig");
const m = @import("main.zig");
const t = @import("terrain.zig");
const fov = @import("shadowcast.zig");

const CommandTag = enum {
    move,
    turn,
    attack,
};

pub const MovementDirection = enum {
    Forward,
    Right,
    Backward,
    Left,
};

const Command = union(enum) {
    move: MovementDirection,
    turn: m.RotationalDirection,
    attack: m.Direction,
};

pub const Player = struct {
    health: i32 = 10,
    inventory: struct {} = .{},
    // pos: m.Uvec2,
    position: m.Ivec3 = .{ .x = 0, .y = 0, .z = 0 },
    // z: usize = 0,
    // facing: m.Direction = .North,
    rotation: f32 = 0,
    speed: f32 = 0,
    // command: ?Command,

    pub fn ivec2(self: Player) m.Ivec2 {
        return m.Ivec2{ .x = @as(i32, @intCast(self.position.x)), .y = @as(i32, @intCast(self.position.y)) };
    }

    pub fn uvec2(self: Player) m.Uvec2 {
        return m.Uvec2{ .x = @as(usize, @intCast(self.position.x)), .y = @as(usize, @intCast(self.position.y)) };
    }

    pub fn uvec3(self: Player) m.Uvec3 {
        return m.Uvec3{ .x = @as(usize, @intCast(self.position.x)), .y = @as(usize, @intCast(self.position.y)), .z = @as(usize, @intCast(self.position.z)) };
    }

    pub fn move(self: *Player, world: *m.World, direction: MovementDirection) !void {
        _ = world;
        _ = direction;
        if (self.position.y >= 1) {
            self.position.y -|= 1; // FIXME
        }
    }
};

const MoveCommandError = error{
    OutOfBounds,
    ImpassableTerrain,
};

pub fn init(world: *m.World) void {
    // FIXME make sure position is valid
    world.player = Player{
        .position = m.Ivec3{ .x = 20, .y = 20, .z = 0 },
        .inventory = .{},
    };
}
