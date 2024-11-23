const rl = @import("raylib");

const std = @import("std");
const logic = @import("logic.zig");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");

pub const World = struct {
    // cell_store: terrain.Cells,
    player: *player.Player,
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    const world = try alloc.create(World);
    errdefer alloc.destroy(world);

    const p = try player.init(alloc);
    errdefer alloc.destroy(p);

    world.player = p;

    terrain.init(alloc);

    gfx.init(alloc);
    gfx.startRunLoop(alloc, world); // calls logic.tick()
    gfx.deinit();
    logic.deinit();
}
