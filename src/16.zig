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

    const ret = try map.solve();

    println(">> {s}:", .{name});
    println("part 1: {}", .{ret.score});
    println("part 2: {}", .{ret.visited});
}

const Vec2 = struct { x: u64, y: u64 };
const Dir = enum { east, west, north, south };

const Map = struct {
    width: usize,
    height: usize,
    grid: [][]Fill,
    start: Vec2,
    final: Vec2,

    seen: struct {
        states: StateSet,
        coords: CoordSet,
    } = undefined,

    const Fill = enum { wall, free, visited };
    const StateSet = std.AutoHashMap(PartialReindeer, u64);
    const CoordSet = std.AutoHashMap(Vec2, void);

    fn fromRaw(raw: []const u8) !Map {
        var grid = try std.ArrayList([]Fill).initCapacity(allocator, 100);
        defer grid.deinit();

        var start = Vec2{ .x = 0, .y = 0 };
        var final = Vec2{ .x = 0, .y = 0 };

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
                    '.' => .free,
                    '#' => .wall,
                    'S' => blk: {
                        start = Vec2{ .x = @intCast(j), .y = @intCast(i) };
                        break :blk .free;
                    },
                    'E' => blk: {
                        final = Vec2{ .x = @intCast(j), .y = @intCast(i) };
                        break :blk .free;
                    },
                    else => unreachable,
                });
            }

            try grid.append(try allocator.dupe(Fill, row.items));
        }
        height = i;

        return .{
            .width = width,
            .height = height,
            .grid = try allocator.dupe([]Fill, grid.items),
            .start = start,
            .final = final,
        };
    }

    fn deinit(map: *Map) void {
        for (map.grid) |row| allocator.free(row);
        allocator.free(map.grid);
    }

    fn solve(map: *Map) !struct { score: u64, visited: u64 } {
        map.seen.states = StateSet.init(allocator);
        defer map.seen.states.deinit();

        map.seen.coords = CoordSet.init(allocator);
        defer map.seen.coords.deinit();

        var pq = std.PriorityQueue(Reindeer, void, Reindeer.pqCompare).init(allocator, {});
        defer pq.deinit();

        var best: u64 = std.math.maxInt(u64);
        var count: usize = 0;

        try pq.add(.{ .pos = map.start });
        while (pq.removeOrNull()) |r| {
            const block = map.get(r.pos) catch continue;
            if (block == .wall) continue;

            if (best < r.cost) break;

            if (r.pos.x == map.final.x and r.pos.y == map.final.y) {
                best = r.cost;
                count += 1;
                continue;
            }

            if (map.seen.states.get(r.partial())) |state_cost| {
                if (state_cost < r.cost) continue;
            }
            try map.seen.states.put(r.partial(), r.cost);

            try pq.add(r.move());
            try pq.add(r.rotateRight());
            try pq.add(r.rotateLeft());
        }

        _ = try map.traverseCachedPaths(.{ .pos = map.start });
        return .{ .score = best, .visited = map.seen.coords.count() + 1 };
    }

    fn traverseCachedPaths(map: *Map, r: Reindeer) !bool {
        const block = map.get(r.pos) catch return false;
        if (block == .wall) return false;

        if (r.pos.x == map.final.x and r.pos.y == map.final.y) return true;

        const state_cost = map.seen.states.get(r.partial()) orelse return false;
        if (state_cost < r.cost) return false;

        var flag = false;
        flag = try traverseCachedPaths(map, r.rotateRight()) or flag;
        flag = try traverseCachedPaths(map, r.rotateLeft()) or flag;
        flag = try traverseCachedPaths(map, r.move()) or flag;

        if (flag) {
            map.grid[@intCast(r.pos.y)][@intCast(r.pos.x)] = .visited;
            try map.seen.coords.put(r.pos, {});
        }

        return flag;
    }

    fn get(map: Map, pos: Vec2) !Fill {
        const x_bouds = 0 <= pos.x and pos.x < map.width;
        const y_bouds = 0 <= pos.y and pos.y < map.height;
        if (!x_bouds or !y_bouds) return error.OutOfBounds;
        return map.grid[@intCast(pos.y)][@intCast(pos.x)];
    }

    fn dbg(map: Map) void {
        for (map.grid, 0..) |row, i| {
            for (row, 0..) |cell, j| {
                if (map.start.x == j and map.start.y == i) {
                    print("S", .{});
                    continue;
                }
                if (map.final.x == j and map.final.y == i) {
                    print("E", .{});
                    continue;
                }
                print("{c}", .{@as(u8, switch (cell) {
                    .wall => '#',
                    .free => '.',
                    .visited => 'O',
                })});
            }
            print("\n", .{});
        }
    }
};

const PartialReindeer = struct { pos: Vec2, dir: Dir };
const Reindeer = struct {
    pos: Vec2,
    dir: Dir = .east,
    cost: u64 = 0,

    fn move(r: Reindeer) Reindeer {
        var cp = r;
        switch (cp.dir) {
            .north => cp.pos.y -= 1,
            .south => cp.pos.y += 1,
            .east => cp.pos.x += 1,
            .west => cp.pos.x -= 1,
        }
        cp.cost += 1;
        return cp;
    }

    fn rotateRight(r: Reindeer) Reindeer {
        var cp = r;
        cp.dir = switch (cp.dir) {
            .north => .east,
            .south => .west,
            .east => .south,
            .west => .north,
        };
        cp.cost += 1000;
        return cp;
    }

    fn rotateLeft(r: Reindeer) Reindeer {
        var cp = r;
        cp.dir = switch (cp.dir) {
            .north => .west,
            .south => .east,
            .east => .north,
            .west => .south,
        };
        cp.cost += 1000;
        return cp;
    }

    fn partial(r: Reindeer) PartialReindeer {
        return .{ .pos = r.pos, .dir = r.dir };
    }

    fn pqCompare(_: void, l: Reindeer, r: Reindeer) std.math.Order {
        if (l.cost < r.cost) return .lt;
        if (l.cost > r.cost) return .gt;
        return .eq;
    }
};

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
