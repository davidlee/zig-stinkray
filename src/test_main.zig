const std = @import("std");
const expect = std.testing.expect;
const t = @import("terrain.zig");
test "sanity test" {
    try expect(true);
}

test "load test terrain" {
    const map = ".#.\n" ++
        "...\n" ++
        ".#.\n";

    //const terrain = try t.loadFromString(map);
    const cells = t.CellStore{};
    const test_allocator = std.testing.allocator_instance.allocator();
    try cells.init(test_allocator);
    try cells.loadFromString(map);
    try expect(cells.items.len == 9);
}
