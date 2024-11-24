const rl = @import("raylib");
const std = @import("std");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");
const input = @import("input.zig");
// const shadowcast = @import("shadowcast.zig");

pub const World = struct {
    cells: terrain.CellStore,
    player: player.Player,
    allocator: std.mem.Allocator, // expanding brain meme - like Odin's default context(?)
    camera: rl.Camera2D,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    // this allocates memory for the CellStore field too
    const world = try alloc.create(World);
    world.allocator = alloc;

    defer alloc.destroy(world);

    player.init(world);
    terrain.init(world);

    gfx.init(world);
    startRunLoop(world);
    gfx.deinit();

    deinit(); // noop
}

// Main game loop
// it's here rather than
pub fn startRunLoop(world: *World) void {
    while (!rl.windowShouldClose()) {
        tick(world);

        rl.beginDrawing();
        defer rl.endDrawing();

        gfx.draw(world);
    }
}

pub fn tick(world: *World) void {
    input.handleKeyboard(world);
    input.handleMouse(world) catch std.log.debug("ERR: handleMouse ", .{});
}

fn deinit() void {}

//
// utility functons .. keep an eye on these
//

// instead of casting usize to isize (risking overflow),
// cast the signed value to usize. Subtract if necessary.
//
// https://ziggit.dev/t/adding-a-signed-integer-to-an-unsigned-integer/5803/3
//
pub fn addSignedtoUsize(u: usize, i: anytype) usize {
    if (i < 0) {
        return u - cast(usize, -i);
    } else {
        return u + cast(usize, i);
    }
}

// short for @as(usize, @intCast(v));
//
inline fn cast(T: type, v: anytype) T {
    return @intCast(v);
}

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

pub const DirectionList = [_]Direction{
    .North,
    .NorthEast,
    .East,
    .SouthEast,
    .South,
    .SouthWest,
    .West,
    .NorthWest,
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

pub const RotationalDirection = enum {
    Counterclockwise,
    None,
    Clockwise,

    pub fn applyToFacing(self: RotationalDirection, dir: Direction) Direction {
        const i = (@intFromEnum(dir) + DirectionList.len + @intFromEnum(self) - 1) % DirectionList.len;
        return DirectionList[i];
    }
};

// vectors
// TODO - is there a library for linear alegebra I should be using ?

pub const Ivec3 = struct { x: i32, y: i32, z: i32 };
pub const Ivec2 = struct { x: i32, y: i32 };

pub const Uvec3 = struct { x: usize, y: usize, z: usize };
pub const Uvec2 = struct { x: usize, y: usize };

pub const Vec3 = struct { x: f32, y: f32, z: f32 };
pub const Vec2 = struct { x: f32, y: f32 };
