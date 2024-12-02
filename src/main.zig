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
    rectangles: std.ArrayList(URect),
    wall_segments: std.ArrayList(WallSegment),
    wall_endpoints: std.ArrayList(WallEndpoint),
    endpoints: EndpointList,

    pub fn init(self: *World, alloc: std.mem.Allocator) void {
        self.allocator = alloc;
        self.cells.init(alloc);

        self.rectangles = std.ArrayList(URect).init(alloc);
        self.wall_segments = std.ArrayList(WallSegment).init(alloc);
        self.wall_endpoints = std.ArrayList(WallEndpoint).init(alloc);
        self.endpoints = EndpointList{};

        self.player.init(self);
        wgen.init(self);
        gfx.init(self);
    }

    pub fn deinit(self: *World) void {
        self.cells.deinit();
        self.rectangles.deinit();
        self.wall_segments.deinit();
        self.wall_endpoints.deinit();

        {
            var it = self.endpoints.pop();
            while (it) |node| : (it = self.endpoints.pop()) {
                self.allocator.destroy(node);
            }
        }
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
    world.init(alloc);
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

// @as(f32, @intFromFloat(f));
pub inline fn intf(T: type, f: anytype) T {
    return @as(T, @intFromFloat(f));
}
// vectors
// TODO - is there a library for linear alegebra I should be using ?

pub const Ivec3 = struct {
    x: i32,
    y: i32,
    z: i32,
};

pub const Ivec2 = struct {
    x: i32,
    y: i32,

    pub fn sub(self: Ivec2, other: Ivec2) Ivec2 {
        return Ivec2{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn subFrom(self: Ivec2, x: anytype, y: anytype) Ivec2 {
        return Ivec2{ .x = cast(i32, x) - self.x, .y = cast(i32, y) - self.y };
    }

    pub fn uvec2(self: Ivec2) Uvec2 {
        return Uvec2{ .x = cast(usize, self.x), .y = cast(usize, self.y) };
    }
};

pub const Uvec3 = struct { x: usize, y: usize, z: usize };
pub const Uvec2 = struct {
    x: usize,
    y: usize,
    pub fn sub(self: Uvec2, other: Uvec2) Uvec2 {
        return Uvec2{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn subFrom(self: Uvec2, x: usize, y: usize) Uvec2 {
        return Uvec2{ .x = x -| self.x, .y = y -| self.y };
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn uvec3(self: Vec3) Uvec3 {
        const x: usize = @intFromFloat(@max(0, self.x));
        const y: usize = @intFromFloat(@max(0, self.y));
        const z: usize = @intFromFloat(@max(0, self.z));

        // FIXME prevent overflow / underflow
        return Uvec3{
            .x = x,
            .y = y,
            .z = z,
        };
    }
    pub fn uvec2(self: Vec3) Uvec2 {
        const x: usize = @intFromFloat(@max(0, self.x));
        const y: usize = @intFromFloat(@max(0, self.y));
        return Uvec2{
            .x = x,
            .y = y,
        };
    }

    pub fn ivec3(self: Vec3) Ivec3 {
        return Ivec3{
            .x = @intFromFloat(self.x),
            .y = @intFromFloat(self.y),
            .z = @intFromFloat(self.z),
        };
    }

    pub fn ivec2(self: Vec3) Ivec2 {
        return Ivec2{
            .x = @intFromFloat(self.x),
            .y = @intFromFloat(self.y),
        };
    }
};
pub const Vec2 = struct {
    x: f32,
    y: f32,
    pub fn uvec2(self: Vec3) Uvec2 {
        const x: usize = @intFromFloat(@max(0, self.x));
        const y: usize = @intFromFloat(@max(0, self.y));
        return Uvec2{
            .x = x,
            .y = y,
        };
    }
};

pub const URect = struct {
    tl: Uvec2, // top left
    br: Uvec2, // bottom right

    pub fn area(self: URect) usize {
        return (self.br.x - self.tl.x) * (self.br.y - self.tl.y + 1);
    }

    pub fn containsPoint(self: URect, point: Uvec2) bool {
        const tl = self.tl;
        const br = self.br;
        return (point.x >= tl.x and point.x < br.x and point.y >= tl.y and point.y < br.y);
    }
};

//
// wall / raycasting
//

pub const WallEndpoint = struct {
    x: f32,
    y: f32,
    angle: f32 = undefined,
    // segment: *WallSegment = undefined,
    top_left: bool = false,

    pub fn cmp(_: void, self: WallEndpoint, other: WallEndpoint) bool {
        return self.angle < other.angle;
    }
};

pub const WallSegment = struct {
    p1: *WallEndpoint,
    p2: *WallEndpoint,
    d: f32 = undefined, // distance squared, avoiding sqrt as an optimisation

    pub fn cmp(_: void, self: WallSegment, other: WallSegment) bool {
        return self.p1.angle < other.p1.angle;
    }
};

pub const Quadrant = enum {
    none,
    q_I, // top right, +,-
    q_II, // top left, -,-
    q_III, // bottom left, -,+
    q_IV, // bottom right, +,+
};

pub const Sign = enum {
    neg,
    zero,
    pos,
    pub fn mult(self: Sign, T: type, x: anytype) T {
        return switch (self) {
            .neg => -x,
            .zero => 0,
            .pos => x,
        };
    }
};

pub const SignPair = struct {
    x: Sign,
    y: Sign,
};

pub const Quadrant_Sign = [5]SignPair{
    .{ .x = .zero, .y = .zero },
    .{ .x = .pos, .y = .neg },
    .{ .x = .neg, .y = .neg },
    .{ .x = .neg, .y = .pos },
    .{ .x = .pos, .y = .pos },
};

// II | I
// ---+---
// III| IV
pub fn quadrant(x: anytype, y: anytype) Quadrant {
    if (x > 0) { // right
        if (y < 0) { // above
            return .q_I;
        } else { // below
            return .q_IV;
        }
    } else if (x < 0) { // left
        if (y < 0) { // above
            return .q_II;
        } else { // below
            return .q_III;
        }
    } else if (y < 0) { // above
        return .q_I;
    } else if (y > 0) { // below
        return .q_IV;
    }
    return .none;
}

pub const EndpointList = std.DoublyLinkedList(WallEndpoint);
