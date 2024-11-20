const rl = @import("raylib");

const logic = @import("logic.zig");
const gfx = @import("graphics.zig");

const std = @import("std");

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    defer {
        _ = gpa.deinit();
    }

    logic.init(alloc);

    gfx.init(alloc);
    gfx.startRunLoop(alloc); // calls logic.tick()
    gfx.deinit();
    logic.deinit();
}
