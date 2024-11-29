const rl = @import("raylib");
const std = @import("std");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");
const input = @import("input.zig");
const wgen = @import("world_gen.zig");
// const shadowcast = @import("shadowcast.zig");

pub const World = struct {
    cells: terrain.CellStore,
    player: player.Player,
    allocator: std.mem.Allocator,
    camera: rl.Camera2D,
    region: std.ArrayList(Uvec2),
    rectangles: std.ArrayList(URect),

    pub fn init(self: *World, alloc: std.mem.Allocator) !void {
        self.allocator = alloc;
        try self.cells.init(alloc);
        player.init(self);
        self.region = try std.ArrayList(Uvec2).initCapacity(alloc, 1000);
        self.rectangles = try std.ArrayList(URect).initCapacity(alloc, 1000);
        wgen.init(self);
        gfx.init(self);
    }

    pub fn deinit(self: *World) void {
        self.cells._arraylist.deinit();
        self.region.deinit();
        self.rectangles.deinit();
        gfx.deinit();
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    const world = try alloc.create(World);
    try world.init(alloc);
    defer alloc.destroy(world);

    startRunLoop(world);

    world.deinit();
}

// Main game loop
pub fn startRunLoop(world: *World) void {
    while (!rl.windowShouldClose()) {
        tick(world);

        gfx.draw(world);
    }
}

pub fn tick(world: *World) void {
    input.handleKeyboard(world);
    input.handleMouse(world) catch std.log.debug("ERR: handleMouse ", .{});
}

//
// utility functons .. keep an eye on these
//

// instead of casting usize to isize (risking overflow),
// cast the signed value to usize. Subtract if necessary, with bounds safety.

pub fn addSignedtoUsize(u: usize, i: anytype) usize {
    if (i < 0) {
        return u -| cast(usize, -i);
    } else {
        return u +| cast(usize, i);
    }
}

// @as(usize, @intCast(v));
//
pub inline fn cast(T: type, v: anytype) T {
    return @intCast(v);
}

// @as(f32, @floatCast(v));
pub inline fn castf(T: type, v: anytype) T {
    return @floatCast(v);
}

// @as(f32, @floatFromInt(i));
pub inline fn flint(T: type, i: anytype) T {
    return @as(T, @floatFromInt(i));
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

pub const URect = struct {
    tl: Uvec2, // top left
    br: Uvec2, // bottom right

    pub fn area(self: URect) usize {
        return (self.br.x - self.tl.x) * (self.br.y - self.tl.y + 1);
    }

    // pub fn contains(self: URect, other: URect) bool {
    //     return self.tl.x <= other.tl.x and self.tl.y <= other.tl.y and self.br.x >= other.br.x and self.br.y >= other.br.y;
    // }

    pub fn containsPoint(self: URect, point: Uvec2) bool {
        const tl = self.tl;
        const br = self.br;
        return (point.x >= tl.x and point.x < br.x and point.y >= tl.y and point.y < br.y);
    }
};
