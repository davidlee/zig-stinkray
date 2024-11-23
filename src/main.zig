const rl = @import("raylib");
const std = @import("std");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");
const input = @import("input.zig");

pub const World = struct {
    cells: *terrain.CellStore,
    player: *player.Player,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    const world = try alloc.create(World);
    defer alloc.destroy(world);

    const p = try player.init(alloc);
    defer alloc.destroy(p);

    world.player = p;

    const cells = try terrain.init(alloc);
    defer alloc.destroy(cells);

    world.cells = cells;

    gfx.init(alloc);
    startRunLoop(alloc, world); // calls logic.tick()
    gfx.deinit();

    // deinit();
}

// Main game loop
pub fn startRunLoop(alloc: std.mem.Allocator, world: *World) void {
    while (!rl.windowShouldClose()) {
        tick(alloc, world);

        rl.beginDrawing();
        defer rl.endDrawing();

        gfx.draw(world);
    }
}

pub fn tick(alloc: std.mem.Allocator, world: *World) void {
    _ = alloc;
    input.handleKeyboard(world);
    input.handleMouse(world);
}

// pub fn deinit() void {}

//
// Types
//

// Directions

pub const Direction = enum {
    North,
    NorthEast,
    East,
    SouthEast,
    South,
    SouthWest,
    West,
    NorthWest,

    pub fn ivec2(self: Direction) Ivec2 {
        return Direction_Vectors[@intFromEnum(self)];
    }
};

pub const Direction_Vectors = [_]Ivec2{
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

// vectors
// TODO - is there a library for linear alegebra I should be using ?

pub const Ivec3 = struct { x: i32, y: i32, z: i32 };
pub const Ivec2 = struct { x: i32, y: i32 };

pub const Uvec3 = struct { x: u16, y: u16, z: u16 };
pub const Uvec2 = struct { x: u16, y: u16 };

pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Vec2 = struct { x: f32, y: f32 };
