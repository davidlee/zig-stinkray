const std = @import("std");
const rl = @import("raylib");
const p = @import("player.zig");
const t = @import("terrain.zig");
const m = @import("main.zig");

const CELL_SIZE = 15;
const MIDPOINT = 8;

var camera: rl.Camera2D = undefined;
var screenWidth: i32 = 0;
var screenHeight: i32 = 0;

pub fn init(world: *m.World) void {
    _ = world;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    screenWidth = rl.getScreenWidth();
    screenHeight = rl.getScreenHeight();
    const fw: f32 = @floatFromInt(screenWidth);
    const fh: f32 = @floatFromInt(screenHeight);
    std.log.debug("{d},{d} - ", .{ fw, fh });

    camera = rl.Camera2D{
        .offset = rl.Vector2.init(fw / 2.0, fh / 2.0),
        .target = rl.Vector2.init(0, 0),
        .rotation = 0,
        .zoom = 1,
    };

    rl.setTargetFPS(60);
}

fn cameraFollowPlayerTarget(world: *m.World) rl.Vector2 {
    const x = world.player.pos.x * CELL_SIZE;
    const y = world.player.pos.y * CELL_SIZE;

    return rl.Vector2.init(
        @floatFromInt(x),
        @floatFromInt(y),
    );
}

pub fn deinit() void {
    defer rl.closeWindow();
}

// FIXME - if using a camera, we have to account for its translation
// NOTE doesn't check bounds
fn pxToCellXY(px: m.Ivec2) m.Uvec2 {
    return m.Uvec2{
        .x = @as(u16, @intCast(px.x)) / CELL_SIZE,
        .y = @as(u16, @intCast(px.y)) / CELL_SIZE,
    };
}

pub fn cellXYatMouse() m.Uvec2 {
    const px = m.Ivec2{ .x = rl.getMouseX(), .y = rl.getMouseY() };
    return pxToCellXY(px);
}

pub fn draw(world: *m.World) void {
    camera.target = cameraFollowPlayerTarget(world);
    camera.rotation = @as(f32, @floatFromInt(@intFromEnum(world.player.facing))) * 45.0;

    rl.clearBackground(rl.Color.dark_gray);
    camera.begin();

    drawCells(world) catch std.log.debug("ERR: DrawCells", .{});
    drawPlayer(&world.player);
    drawRegion(world);

    camera.end();
}

// TODO maybe worth exploring: after terrain generation,
// visit each cell's neighbours and store a bitmask which encodes which neighbours
// block line of sight; probably 4 bits is enough.
// it's likely to help with edge / wall detection at runtime
// (although I never want to have to care about cache invalidation)

fn drawRegion(world: *m.World) void {
    // let's find nearby cells and draw lines to their "significant corners"
    // we can work out wall detection and culling later.
    //
    const pos = world.player.pos;

    const nw = 0b1000;
    const ne = 0b0100;
    const se = 0b0010;
    const sw = 0b0001;

    // each cell has 4 corners. considering only single cells and not walls:
    // one is usually out of sight;
    // sometimes two, if x or y are equal to the viewer.
    // in the usual case where three corners are visible,
    // only the two on the outside mark boundaries.

    // const significant_corners: [_]u4 = .{ // NW NE SE SW
    //     0b0101,0b0011,0b1010, // y < (above)
    //     0b0110,0b0000,0b1001, // player
    //     0b1010,0b1100,0b0101, // y > (below)
    //     // x < player > x
    //     // left       right
    // };

    const px = m.cast(i32, pos.x * CELL_SIZE + MIDPOINT);
    const py = m.cast(i32, pos.y * CELL_SIZE + MIDPOINT);

    // neither efficient nor elegant. that's ok for now.
    // this code won't stay..
    //
    // NOTE: if we're iterating over cells around the player
    // we could make assumptions about ordering to improve perf

    for (world.region.items) |xy| {
        var corners: u4 = 0b0000;

        if (xy.x == pos.x) {
            if (xy.y < pos.y) { // directly above player
                corners = (se ^ sw);
            } else { // directly below
                corners = (ne ^ nw);
            }
        } else if (xy.y == pos.y) {
            if (xy.x < pos.x) { // directly left of player
                corners = (ne ^ se);
            } else { // directly right
                corners = (nw ^ sw);
            }
        } else {
            if (xy.x < pos.x) {
                if (xy.y < pos.y) { // it's above left
                    corners = (sw ^ ne);
                } else { // below left
                    corners = (nw ^ se);
                }
            } else {
                if (xy.y < pos.y) { // it's above right
                    corners = (nw ^ se);
                } else { // below right
                    corners = (sw ^ ne);
                }
            }
        }

        const ax = m.cast(i32, xy.x * CELL_SIZE);
        const ay = m.cast(i32, xy.y * CELL_SIZE);
        const bx = m.cast(i32, (xy.x + 1) * CELL_SIZE);
        const by = m.cast(i32, (xy.y + 1) * CELL_SIZE);

        if (corners & nw > 0) {
            rl.drawLine(px, py, ax, ay, rl.Color.black);
        }
        if (corners & ne > 0) {
            rl.drawLine(px, py, bx, ay, rl.Color.black);
        }
        if (corners & se > 0) {
            rl.drawLine(px, py, bx, by, rl.Color.black);
        }
        if (corners & sw > 0) {
            rl.drawLine(px, py, ax, by, rl.Color.black);
        }
    }
}

fn drawPlayer(player: *p.Player) void {
    const x = player.pos.x * CELL_SIZE;
    const y = player.pos.y * CELL_SIZE;

    rl.drawRectangle(@intCast(x), @intCast(y), CELL_SIZE, CELL_SIZE, rl.Color.red);
}

// TODO only draw visible cells
//
fn drawCells(world: *m.World) !void {
    // const pos = world.player.pos;
    // const cells = try world.cells.getVisible(pos.x, pos.y, world.player.z, 150, 30);

    for (world.cells._arraylist.items, 0..) |cell, i| {
        const xy = try world.cells.XYZof(i);

        const px: i32 = @intCast(xy[0] * CELL_SIZE);
        const py: i32 = @intCast(xy[1] * CELL_SIZE);

        switch (cell.tile) {
            .Empty => rl.drawRectangle(
                px,
                py,
                CELL_SIZE,
                CELL_SIZE,
                rl.Color.dark_gray,
            ),
            .Floor => |mat| {
                switch (mat) {
                    .Iron => {
                        rl.drawRectangle(
                            px,
                            py,
                            CELL_SIZE,
                            CELL_SIZE,
                            rl.Color.init(20, 30, 20, 255),
                        );
                        rl.drawRectangle(
                            px + 3,
                            py + 3,
                            4,
                            4,
                            rl.Color.init(50, 50, 40, 255),
                        );
                    },
                    else => {
                        rl.drawRectangle(
                            px,
                            py,
                            CELL_SIZE,
                            CELL_SIZE,
                            rl.Color.init(48, 33, 22, 255),
                        );
                        rl.drawRectangle(
                            px + 4,
                            py + 4,
                            4,
                            4,
                            rl.Color.init(18, 25, 44, 255),
                        );
                    },
                }
            },
            .Solid => rl.drawRectangle(
                px,
                py,
                CELL_SIZE,
                CELL_SIZE,
                rl.Color.black,
            ),
        }
    }
}
