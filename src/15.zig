const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Vec2 = struct { x: i64 = 0, y: i64 = 0 };
const Fill = enum { wall, box, box_left, box_right, free };
const Map = struct {
    width: usize,
    height: usize,
    grid: [][]Fill,
    input: []u8,
    bot: Vec2,

    fn fromRaw(raw: []const u8, comptime wide: bool) !Map {
        var map = Map{
            .width = 0,
            .height = 0,
            .grid = undefined,
            .input = undefined,
            .bot = .{},
        };

        var grid = std.ArrayList([]Fill).init(allocator);
        defer grid.deinit();

        var i: usize = 0;
        var lines = std.mem.splitScalar(u8, raw, '\n');
        while (lines.next()) |line| : (i += 1) {
            if (line.len == 0) break;

            var row = std.ArrayList(Fill).init(allocator);
            defer row.deinit();

            map.width = if (wide) 2 * line.len else line.len;

            for (line, 0..) |c, j| {
                var pos: Fill = switch (c) {
                    '#' => .wall,
                    '.' => .free,
                    'O' => if (wide) .box_left else .box,
                    '@' => blk: {
                        const x = if (wide) 2 * j else j;
                        map.bot = .{ .x = @intCast(x), .y = @intCast(i) };
                        break :blk .free;
                    },
                    else => unreachable,
                };
                try row.append(pos);
                if (wide) {
                    if (pos == .box_left) pos = .box_right;
                    try row.append(pos);
                }
            }
            try grid.append(try allocator.dupe(Fill, row.items));
        }
        map.grid = try allocator.dupe([]Fill, grid.items);
        map.height = i;

        var input = std.ArrayList([]const u8).init(allocator);
        defer input.deinit();
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            try input.append(line);
        }
        map.input = try std.mem.concat(allocator, u8, input.items);

        return map;
    }

    fn deinit(map: *Map) void {
        for (map.grid) |row| allocator.free(row);
        allocator.free(map.grid);
        allocator.free(map.input);
    }

    fn applyInput(map: *Map) void {
        for (map.input) |char| {
            const dir = switch (char) {
                '<' => Vec2{ .x = -1, .y = 0 },
                '^' => Vec2{ .x = 0, .y = -1 },
                '>' => Vec2{ .x = 1, .y = 0 },
                'v' => Vec2{ .x = 0, .y = 1 },
                else => unreachable,
            };
            const new_pos = Vec2{ .x = dir.x + map.bot.x, .y = dir.y + map.bot.y };
            if (map.tryMove(new_pos, dir)) map.bot = new_pos;
        }
    }

    fn boxesGps(map: Map) u64 {
        var ans: u64 = 0;
        for (map.grid, 0..) |row, i| {
            for (row, 0..) |pos, j| {
                if (pos == .box or pos == .box_left) ans += i * 100 + j;
            }
        }
        return ans;
    }

    fn tryMove(map: *Map, coord: Vec2, dir: Vec2) bool {
        if (!map.checkMove(coord, dir)) return false;
        map.moveNoCheck(.free, coord, dir);
        return true;
    }

    fn checkMove(map: *Map, coord: Vec2, dir: Vec2) bool {
        const cur_fill = map.get(coord.y, coord.x) catch return false;
        switch (cur_fill) {
            .wall => return false,
            .free => return true,
            .box, .box_left, .box_right => {
                if (cur_fill == .box or dir.y == 0) {
                    const new = Vec2{ .x = dir.x + coord.x, .y = dir.y + coord.y };
                    return map.checkMove(new, dir);
                }

                const x_anchor = if (cur_fill == .box_right) coord.x - 1 else coord.x;
                const new_l = Vec2{ .x = x_anchor, .y = coord.y + dir.y };
                const new_r = Vec2{ .x = x_anchor + 1, .y = coord.y + dir.y };

                return map.checkMove(new_l, dir) and map.checkMove(new_r, dir);
            },
        }
    }

    fn moveNoCheck(map: *Map, fill: Fill, coord: Vec2, dir: Vec2) void {
        defer map.grid[@intCast(coord.y)][@intCast(coord.x)] = fill;
        const cur_fill = map.get(coord.y, coord.x) catch unreachable;
        switch (cur_fill) {
            .wall => unreachable,
            .free => return,
            .box, .box_right, .box_left => {
                if (cur_fill == .box or dir.y == 0) {
                    const new = Vec2{ .x = dir.x + coord.x, .y = dir.y + coord.y };
                    return map.moveNoCheck(cur_fill, new, dir);
                }

                const x_anchor = if (cur_fill == .box_right) coord.x - 1 else coord.x;
                const coord_l = Vec2{ .x = x_anchor, .y = coord.y + dir.y };
                const coord_r = Vec2{ .x = x_anchor + 1, .y = coord.y + dir.y };

                map.moveNoCheck(.box_left, coord_l, dir);
                map.moveNoCheck(.box_right, coord_r, dir);

                switch (cur_fill) {
                    .box_left => map.grid[@intCast(coord.y)][@intCast(coord.x + 1)] = .free,
                    .box_right => map.grid[@intCast(coord.y)][@intCast(coord.x - 1)] = .free,
                    else => unreachable,
                }
            },
        }
    }

    fn get(map: Map, i: i64, j: i64) !Fill {
        const i_bounds = 0 <= i and i < map.height;
        const j_bounds = 0 <= j and j < map.width;
        if (!i_bounds or !j_bounds) return error.OutOfBounds;
        return map.grid[@intCast(i)][@intCast(j)];
    }

    fn dbg(map: Map) void {
        for (map.grid, 0..) |row, i| {
            for (row, 0..) |cell, j| {
                if (i == map.bot.y and j == map.bot.x) {
                    print("@", .{});
                    continue;
                }
                print("{c}", .{@as(u8, switch (cell) {
                    .wall => '#',
                    .box => 'O',
                    .box_left => '[',
                    .box_right => ']',
                    .free => '.',
                })});
            }
            println("", .{});
        }
    }
};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    println(">> {s}:", .{name});
    {
        var map = try Map.fromRaw(@embedFile(name), false);
        defer map.deinit();
        println("part 1: {}", .{try part1(&map)});
    }
    {
        var map = try Map.fromRaw(@embedFile(name), true);
        defer map.deinit();
        println("part 2: {}", .{try part2(&map)});
    }
}

fn part1(map: *Map) !u64 {
    map.applyInput();
    return map.boxesGps();
}

fn part2(map: *Map) !u64 {
    map.applyInput();
    return map.boxesGps();
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
