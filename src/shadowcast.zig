const std = @import("std");
// const m = @import("main.zig");
const r = std.math.big.Rational;

const Vec2 = struct { x: u16, y: u16 };
const Angle = r;
const Callback = *const fn (x: u16, y: u16) void;

// pub fn init()

pub fn shadowcast(
    origin: Vec2,
    range: u16,
    is_blocking: Callback,
    mark_visible: Callback,
) void {
    _ = .{ origin, range, is_blocking, mark_visible };
}

fn markVisible(
    cell: Vec2,
) void {
    _ = cell;
}

fn isBlocking(
    cell: Vec2,
) void {
    _ = cell;
}
