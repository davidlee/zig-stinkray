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
    position: m.Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    velocity: m.Vec3 = .{ .x = 0, .y = 0, .z = 0 },
    rotation: f32 = 0,
    speed: f32 = 0,
    // command: ?Command,

    // pub fn ivec2(self: Player) m.Ivec2 {
    //     return m.Ivec2{ .x = @as(i32, @intFromFloat(self.position.x)), .y = @as(i32, @intFromFloat(self.position.y)) };
    // }

    // pub fn uvec2(self: Player) m.Uvec2 {
    //     return m.Uvec2{ .x = @as(usize, @intFromFloat(self.position.x)), .y = @as(usize, @intFromFloat(self.position.y)) };
    // }

    // pub fn uvec3(self: Player) m.Uvec3 {
    //     return m.Uvec3{ .x = @as(usize, @intFromFloat(self.position.x)), .y = @as(usize, @intFromFloat(self.position.y)), .z = @as(usize, @intFromFloat(self.position.z)) };
    // }

    pub fn move(self: *Player, world: *m.World, direction: MovementDirection) !void {
        const a: f32 = switch (direction) {
            .Forward => 0,
            .Right => 90,
            .Backward => 180,
            .Left => 270,
        };
        const r = (self.rotation + a - 90) * std.math.pi / 180.0;
        const dist = 0.3;
        // std.debug.print("move {d} {d}\n", .{ r, a });
        const new_pos = m.Vec3{
            .x = self.position.x + @cos(r) * dist,
            .y = self.position.y + @sin(r) * dist,
            .z = self.position.z,
        };
        // std.debug.print("new_pos {d} {d}\n", .{ new_pos.x, new_pos.y });

        if (world.cells.isValidPlayerPosition(new_pos) catch false) {
            self.position = new_pos;
        } else {
            // std.log.debug("move to {d},{d} failed", .{ new_pos.x, new_pos.y });
        }
    }
};

const MoveCommandError = error{
    OutOfBounds,
    ImpassableTerrain,
};

pub fn init(world: *m.World) void {
    _ = world;
}
