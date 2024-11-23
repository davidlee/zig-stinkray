const rl = @import("raylib");

const std = @import("std");
const logic = @import("logic.zig");
const gfx = @import("graphics.zig");
const terrain = @import("terrain.zig");
const player = @import("player.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    terrain.init(alloc);

    gfx.init(alloc);
    gfx.startRunLoop(alloc); // calls logic.tick()
    gfx.deinit();
    logic.deinit();
}
