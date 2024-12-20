const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var map = try Map.fromRaw(@embedFile(name));
    defer map.deinit();

    try map.reverseBfs();
    println(">> {s}:", .{name});
    println("part 1: {}", .{try map.findShortcuts(2)});
    println("part 2: {}", .{try map.findShortcuts(20)});
}

const Map = struct {
    start: Vec2,
    end: Vec2,

    width: usize,
    height: usize,
    grid: [][]Fill,

    const Fill = enum(i32) { wall = -1, unmapped = std.math.maxInt(i32), _ };
    const Shortcut = struct { beg: Vec2, end: Vec2 };

    fn fromRaw(raw: []const u8) !Map {
        var grid = try std.ArrayList([]Fill).initCapacity(allocator, 100);
        defer grid.deinit();

        var start = Vec2{ .x = 0, .y = 0 };
        var end = Vec2{ .x = 0, .y = 0 };
        var width: usize = 0;
        var height: usize = 0;

        var i: usize = 0;
        var lines = std.mem.splitScalar(u8, raw, '\n');
        while (lines.next()) |line| : (i += 1) {
            if (line.len == 0) break;

            var row = try std.ArrayList(Fill).initCapacity(allocator, 100);
            defer row.deinit();

            width = line.len;
            for (line, 0..) |char, j| {
                try row.append(switch (char) {
                    '#' => .wall,
                    '.' => .unmapped,
                    'S' => blk: {
                        start = Vec2{ .x = @intCast(j), .y = @intCast(i) };
                        break :blk .unmapped;
                    },
                    'E' => blk: {
                        end = Vec2{ .x = @intCast(j), .y = @intCast(i) };
                        break :blk @enumFromInt(0);
                    },
                    else => unreachable,
                });
            }
            try grid.append(try allocator.dupe(Fill, row.items));
        }
        height = i;

        return .{
            .start = start,
            .end = end,
            .width = width,
            .height = height,
            .grid = try allocator.dupe([]Fill, grid.items),
        };
    }

    fn deinit(map: *Map) void {
        for (map.grid) |row| allocator.free(row);
        allocator.free(map.grid);
    }

    const PQPair = struct { Vec2, u64 };

    fn pqCompare(_: void, l: PQPair, r: PQPair) std.math.Order {
        if (l[1] < r[1]) return .lt;
        if (l[1] > r[1]) return .gt;
        return .eq;
    }

    fn reverseBfs(map: *Map) !void {
        var pq = std.PriorityQueue(PQPair, void, pqCompare).init(allocator, {});
        defer pq.deinit();

        try pq.add(.{ map.end, 0 });
        while (pq.removeOrNull()) |cur| {
            const cell = map.get(cur[0]) catch continue;
            switch (cell.*) {
                .wall => continue,
                else => |*val| {
                    if (@intFromEnum(val.*) < cur[1]) continue;
                    val.* = @enumFromInt(cur[1]);
                },
            }
            inline for ([_]Vec2{ .{ .x = 1 }, .{ .x = -1 }, .{ .y = 1 }, .{ .y = -1 } }) |dir| {
                const new_pos = Vec2{ .x = cur[0].x + dir.x, .y = cur[0].y + dir.y };
                try pq.add(.{ new_pos, cur[1] + 1 });
            }
        }
    }

    fn findShortcuts(map: *Map, fase_max: u64) !u64 {
        var pq = std.PriorityQueue(PQPair, void, pqCompare).init(allocator, {});
        defer pq.deinit();

        var buckets = std.AutoHashMap(u64, u64).init(allocator);
        defer buckets.deinit();

        var cur_beg: ?Vec2 = map.start;
        while (cur_beg) |beg| : (cur_beg = map.nextInPath(beg)) {
            const lo_i = @as(u64, @intCast(beg.y)) -| fase_max;
            const hi_i = @min(map.height, @as(u64, @intCast(beg.y)) + fase_max + 1);
            for (lo_i..hi_i) |i| {
                const lo_j = @as(u64, @intCast(beg.x)) -| fase_max;
                const hi_j = @min(map.width, @as(u64, @intCast(beg.x)) + fase_max + 1);
                for (lo_j..hi_j) |j| {
                    const dist_x = @abs(beg.x - @as(i64, @intCast(j)));
                    const dist_y = @abs(beg.y - @as(i64, @intCast(i)));
                    const dist = dist_x + dist_y;
                    if (fase_max < dist) continue;

                    const end = Vec2{ .x = @intCast(j), .y = @intCast(i) };
                    const beg_height = map.getHeight(beg) catch continue;
                    const end_height = map.getHeight(end) catch continue;
                    const saved = beg_height -| end_height;
                    if (saved <= dist) continue;

                    const ret = try buckets.getOrPut(saved - dist);
                    ret.value_ptr.* = if (ret.found_existing) ret.value_ptr.* + 1 else 1;
                }
            }
        }

        var ans: u64 = 0;
        var bucket_it = buckets.iterator();
        while (bucket_it.next()) |item| {
            if (item.key_ptr.* >= 100) ans += item.value_ptr.*;
        }
        return ans;
    }

    inline fn get(map: Map, pos: Vec2) !*Fill {
        const x_bouds = 0 <= pos.x and pos.x < map.width;
        const y_bouds = 0 <= pos.y and pos.y < map.height;
        if (!x_bouds or !y_bouds) return error.OutOfBounds;
        return &map.grid[@intCast(pos.y)][@intCast(pos.x)];
    }

    inline fn nextInPath(map: Map, pos: Vec2) ?Vec2 {
        const cur_height = map.getHeight(pos) catch return null;
        inline for ([_]Vec2{ .{ .x = 1 }, .{ .x = -1 }, .{ .y = 1 }, .{ .y = -1 } }) |dir| {
            const new_pos = Vec2{ .x = pos.x + dir.x, .y = pos.y + dir.y };
            const new_height = map.getHeight(new_pos) catch cur_height;
            if (cur_height == new_height + 1) return new_pos;
        }
        return null;
    }

    inline fn getHeight(map: Map, pos: Vec2) !u64 {
        const cell = try map.get(pos);
        return switch (cell.*) {
            .wall => error.Blocked,
            else => |val| @intCast(@intFromEnum(val)),
        };
    }
};

const Vec2 = struct { x: i64 = 0, y: i64 = 0 };

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
