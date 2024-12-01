const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");

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
    mouse_look_mode: bool = false,

    pub fn turn(self: *Player, direction: MovementDirection) void {
        self.rotation += switch (direction) {
            .Right => 5,
            .Left => -5,
            else => 0,
        };
    }

    pub fn move(self: *Player, world: *m.World, direction: MovementDirection) void {
        const a: f32 = switch (direction) {
            .Forward => 0,
            .Right => 90,
            .Backward => 180,
            .Left => 270,
        };

        const r = (self.rotation + a - 90) * std.math.pi / 180.0;
        const dist = 0.3;
        const max = world.cells.getSize();

        // this causes a panic in math.clamp so we have to do things the long way
        // const broken: f32 = std.math.clamp(0, 50.249847, 50);

        const x1: f32 = @min(m.flint(f32, max.x), @max(0, self.position.x + @cos(r) * dist));
        const y1: f32 = @min(m.flint(f32, max.y), @max(0, self.position.y + @sin(r) * dist));
        const z1: f32 = self.position.z;
        const new_pos = m.Vec3{ .x = x1, .y = y1, .z = z1 };

        if (world.cells.isValidPlayerPosition(new_pos) catch false) {
            self.position = new_pos;
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
