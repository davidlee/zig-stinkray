const std = @import("std");
const rng = std.crypto.random;

const rl = @import("raylib");
const znoise = @import("znoise");
const t = @import("terrain.zig");

const input = @import("input.zig");
const player = @import("player.zig");
const m = @import("main.zig");

pub fn init(world: *m.World) void {
    initMap(world);
}

fn initMap(world: *m.World) void {
    genTerrainNoise(&world.cells) catch std.log.debug("ERR: genTerrainNoise", .{});
    genRooms(world) catch std.log.debug("ERR: getRooms", .{});
}

fn genTerrainNoise(cells: *t.CellStore) !void {
    const gen = znoise.FnlGenerator{
        .frequency = 0.12,
    };

    const k = 0.35;

    for (0..cells._arraylist.capacity) |i| {
        const xy = try cells.xyzOf(i);

        const noiseX: f32 = @floatFromInt(xy.x);
        const noiseY: f32 = @floatFromInt(xy.y);

        if (gen.noise2(noiseX, noiseY) > k) {
            const cell = t.Cell{ .tile = t.Tile{ .Solid = .Stone } };
            cells._setInitial(i, cell);
        } else {
            const cell = t.Cell{ .tile = t.Tile{ .Floor = .Dirt } };
            cells._setInitial(i, cell);
        }
    }
}

// TODO keep metadata about rooms after build
// connect rooms with passageways
// choose a room & location for some things like entry & exit location
// add treasure, places of interest
// FIXME handle all Z indexes
// TEST check off by one errors
const Room = struct { x: usize, y: usize, width: usize, height: usize };

const ROOM_SIZE = .{ .min = 4, .max = 30 };
const ROOM_COUNT = .{ .min = 4, .max = 20 };

fn genRooms(world: *m.World) !void {
    const count = rng.uintLessThanBiased(u16, ROOM_COUNT.max - ROOM_COUNT.min) + ROOM_COUNT.min;
    const size_range = ROOM_SIZE.max - ROOM_SIZE.min;
    const z = 0; // FIXME

    var rooms: [ROOM_COUNT.max]Room = undefined;

    for (0..count) |i| {
        const size = .{
            .width = rng.uintLessThanBiased(usize, size_range) + ROOM_COUNT.min,
            .height = rng.uintLessThanBiased(usize, size_range) + ROOM_COUNT.min,
        };

        // allow for a 1 cell border
        const origin_max = .{
            .x = t.MAX.x - size.width - 2,
            .y = t.MAX.y - size.height - 2,
        };

        // account for room size in placement
        const origin = m.Uvec2{
            .x = rng.uintLessThanBiased(usize, origin_max.x) + 1,
            .y = rng.uintLessThanBiased(usize, origin_max.y) + 1,
        };

        const room = Room{
            .x = origin.x,
            .y = origin.y,
            .width = size.width,
            .height = size.height,
        };

        // excavate rooms
        for (room.x..room.x + room.width) |x| {
            for (room.y..room.y + room.height) |y| {
                const cell = t.Cell{ .tile = t.Tile{ .Floor = .Iron } };
                try world.cells.set(x, y, z, cell);
            }
        }

        rooms[i] = room;
    }

    // TODO
    // draw corridoors, doors, etc
    // store room definitions / metadata -> treasure tables, etc
    // non-rectangular rooms & overlap:
    //   generate rect. rooms as above
    //   check for collisions
    //   randomly union / subtract / reject collisions
    //   will need to describe rooms in metadata using an array or bitmask ..
}
