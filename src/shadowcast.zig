const std = @import("std");
const m = @import("main.zig");
const t = @import("terrain.zig");
const p = @import("player.zig");

// https://www.albertford.com/shadowcasting/
// https://en.wikipedia.org/wiki/Visibility_polygon
// https://www.redblobgames.com/articles/visibility/
// https://github.com/CGAL/cgal/blob/master/Visibility_2/include/CGAL/Rotational_sweep_visibility_2.h

const r = std.math.big.Rational;

const Uvec2 = struct { x: usize, y: usize };
const Angle = r;
const CallbackXY = *const fn (x: usize, y: usize) void;
const CallbackXYZ = *const fn (x: usize, y: usize, z: usize) void;

// pub fn init()

var _world: *m.World = undefined;
var _cell_store: *t.CellStore = undefined;
var _vis_map_owner: *p.Player = undefined;

// let's make it dumb and hardcode stuff for now, and
// generalise / abstract interfaces out later
pub fn init(world: *m.World, store: *t.CellStore, vis: *p.Player) void {
    _world = world;
    _cell_store = store;
    _vis_map_owner = vis;
}

pub fn shadowcast(
    origin: Uvec2,
    range: usize,
    // is_blocking: *const fn (x: usize, y: usize, z: usize) void,
    // mark_visible: *const fn (x: usize, y: usize) void,
) void {
    _ = .{ origin, range };
}

// fn markVisible(
//     cell: Uvec2,
// ) void {
//     _ = cell;
// }

// fn isBlocking(
//     cell: Uvec2,
// ) void {
//     _ = cell;
// }
