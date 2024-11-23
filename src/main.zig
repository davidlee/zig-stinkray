const rl = @import("raylib");

const std = @import("std");
const logic = @import("logic.zig");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");

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
    gfx.startRunLoop(alloc, world); // calls logic.tick()
    gfx.deinit();
    logic.deinit();
}
