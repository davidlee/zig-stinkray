const std = @import("std");
const t = @import("terrain.zig");
const expect = std.testing.expect;

pub fn loadFromString(allocator: std.mem.Allocator, string: []const u8) *t.CellStore {
    var lines = std.mem.splitScalar(u8, string, '\n');
    var cells = allocator.create(t.CellStore) catch unreachable;
    cells._arraylist = std.ArrayList(t.Cell).init(allocator);
    cells._height = 0;

    while (lines.next()) |line| {
        if (line.len > 0) {
            cells._width = line.len;
            cells._height += 1;
        }
        for (line) |ch| {
            const cell: t.Cell = switch (ch) {
                '#' => t.Cell{ .tile = t.Tile{ .Solid = .Stone } },
                '.' => t.Cell{ .tile = t.Tile{ .Floor = .Dirt } },
                else => t.Cell{ .tile = .Empty },
            };
            cells._arraylist.append(cell) catch unreachable;
        }
    }
    cells._depth = 1;
    return cells;
}

test "getRect 3x3" {
    const map =
        "..#..\n" ++ // ..#..       .#.
        ".###.\n" ++ // .###.  ->   ###
        "..#..\n"; //   ..#..       .#.

    const test_allocator = std.testing.allocator_instance.allocator();
    const cells = loadFromString(test_allocator, map);
    defer test_allocator.destroy(cells);
    defer cells._arraylist.deinit();

    try std.testing.expectEqual(5, cells.getWidth());
    try std.testing.expectEqual(3, cells.getHeight());
    try std.testing.expectEqual(1, cells.getDepth());
    try std.testing.expectEqual(15, cells._arraylist.items.len);

    var rl = std.ArrayList(t.RectAddr).init(test_allocator); // unfortunate name
    defer rl.deinit();

    const mid_x = cells.getWidth() / 2;
    const mid_y = cells.getHeight() / 2;

    cells.getRect(&rl, mid_x, mid_y, 0, 3, 3);
    try std.testing.expectEqual(9, rl.items.len);

    var expected = ".#." ++ "###" ++ ".#.";
    var o: [9]u8 = undefined;
    for (rl.items, 0..) |it, i| {
        o[i] = switch (it.cell.tile) {
            .Empty => '.',
            .Floor => '.',
            .Solid => '#',
        };
    }
    try std.testing.expectEqualSlices(u8, expected[0..], o[0..]);
}
