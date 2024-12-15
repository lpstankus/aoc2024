const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Vec2 = struct { x: i64, y: i64 };
const Rect = struct {
    anchor: Vec2,
    size: Vec2,

    inline fn contains(rect: Rect, pos: Vec2) bool {
        if (pos.x < rect.anchor.x or rect.anchor.x + rect.size.x <= pos.x) return false;
        if (pos.y < rect.anchor.y or rect.anchor.y + rect.size.y <= pos.y) return false;
        return true;
    }
};

const Robot = struct { pos: Vec2, spd: Vec2 };
const Map = struct {
    width: i64,
    height: i64,
    bots: std.ArrayList(Robot),
    grid: [][]u8,

    fn fromRaw(raw: []const u8, comptime example: bool) !Map {
        var bots = std.ArrayList(Robot).init(allocator);

        var lines = std.mem.splitScalar(u8, raw, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) break;
            var it = std.mem.splitAny(u8, line, "=, ");
            _ = it.next();
            const pos = Vec2{
                .x = try std.fmt.parseInt(i64, it.next().?, 10),
                .y = try std.fmt.parseInt(i64, it.next().?, 10),
            };
            _ = it.next();
            const spd = Vec2{
                .x = try std.fmt.parseInt(i64, it.next().?, 10),
                .y = try std.fmt.parseInt(i64, it.next().?, 10),
            };
            try bots.append(Robot{ .pos = pos, .spd = spd });
        }

        const width = comptime if (example) 11 else 101;
        const height = comptime if (example) 7 else 103;
        const grid = try allocator.alloc([]u8, height);
        for (grid) |*row| row.* = try allocator.alloc(u8, width);

        return .{ .width = width, .height = height, .bots = bots, .grid = grid };
    }

    fn deinit(map: *Map) void {
        map.bots.deinit();
        for (map.grid) |row| allocator.free(row);
        allocator.free(map.grid);
    }

    fn step(map: *Map) void {
        for (map.bots.items) |*bot| {
            bot.pos.x = @mod((bot.pos.x + bot.spd.x), map.width);
            bot.pos.y = @mod((bot.pos.y + bot.spd.y), map.height);
        }
    }

    fn checkTree(map: Map) bool {
        for (map.grid) |*row| @memset(row.*, '.');
        for (map.bots.items) |bot| map.grid[@intCast(bot.pos.y)][@intCast(bot.pos.x)] = 'X';
        var longest_streak: u64 = 0;
        for (map.grid) |row| {
            var streak: u64 = 0;
            for (row) |char| {
                switch (char) {
                    '.' => streak = 0,
                    'X' => {
                        streak += 1;
                        longest_streak = @max(longest_streak, streak);
                    },
                    else => unreachable,
                }
            }
        }
        return longest_streak >= 15;
    }

    fn countQuadrants(map: Map) [4]u64 {
        var ret = [_]u64{ 0, 0, 0, 0 };
        const quad_width = @divFloor(map.width, 2);
        const quad_height = @divFloor(map.height, 2);
        const quads = [_]Rect{
            Rect{
                .anchor = Vec2{ .x = 0, .y = 0 },
                .size = Vec2{ .x = quad_width, .y = quad_height },
            },
            Rect{
                .anchor = Vec2{ .x = quad_width + 1, .y = 0 },
                .size = Vec2{ .x = quad_width, .y = quad_height },
            },
            Rect{
                .anchor = Vec2{ .x = 0, .y = quad_height + 1 },
                .size = Vec2{ .x = quad_width, .y = quad_height },
            },
            Rect{
                .anchor = Vec2{ .x = quad_width + 1, .y = quad_height + 1 },
                .size = Vec2{ .x = quad_width, .y = quad_height },
            },
        };
        outer: for (map.bots.items) |bot| {
            for (quads, 0..) |quad, i| {
                if (quad.contains(bot.pos)) {
                    ret[i] += 1;
                    continue :outer;
                }
            }
        }
        return ret;
    }
};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    println(">> {s}:", .{name});
    const is_example = comptime std.mem.eql(u8, name, "example");
    {
        var map = try Map.fromRaw(@embedFile(name), is_example);
        defer map.deinit();
        println("part 1: {}", .{try part1(&map)});
    }
    if (!is_example) {
        var map = try Map.fromRaw(@embedFile(name), is_example);
        defer map.deinit();
        println("part 2: {}", .{try part2(&map)});
    }
}

fn part1(map: *Map) !u64 {
    var ans: u64 = 1;
    for (0..100) |_| map.step();
    for (map.countQuadrants()) |count| ans *= count;
    return ans;
}

fn part2(map: *Map) !u64 {
    for (0..8_000) |i| {
        if (map.checkTree()) return i;
        map.step();
    }
    return error.FailedToFindTree;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
