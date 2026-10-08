const std = @import("std");

var gpa = std.heap.DebugAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var garden = try GardenPlots.fromRaw(@embedFile(name));
    defer garden.deinit();

    const regions = try garden.calculateRegions();
    defer regions.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{try part1(regions)});
    println("part 2: {}", .{try part2(regions)});
}

const Dir = enum { up, down, left, right };
const Rotation = enum { clock, anticlock };
const Pos = struct { i: i64, j: i64, dir: Dir = .right };
const BorderMap = std.AutoHashMap(Pos, void);

const Region = struct { id: u8, area: u64, perimeter: u64, sides: u64 = 0 };
const Plant = struct { id: u8, visited: bool };

const GardenPlots = struct {
    plot_map: [][]Plant,
    border_map: BorderMap,

    fn fromRaw(raw: []const u8) !GardenPlots {
        var plots = std.array_list.Managed([]Plant).init(allocator);
        defer plots.deinit();

        var lines = std.mem.splitScalar(u8, raw, '\n');
        while (lines.next()) |row| {
            if (row.len == 0) break;
            const plants = try allocator.alloc(Plant, row.len);
            for (row, 0..) |plant, i| plants[i] = Plant{ .id = plant, .visited = false };
            try plots.append(plants);
        }

        return .{
            .plot_map = try allocator.dupe([]Plant, plots.items),
            .border_map = BorderMap.init(allocator),
        };
    }

    fn deinit(g: *GardenPlots) void {
        for (g.plot_map) |row| allocator.free(row);
        allocator.free(g.plot_map);
        g.border_map.deinit();
    }

    fn calculateRegions(g: *GardenPlots) !std.array_list.Managed(Region) {
        var regions = std.array_list.Managed(Region).init(allocator);
        for (g.plot_map, 0..) |row, i| {
            for (row, 0..) |plant, j| {
                const idx: i64 = @intCast(i);
                const jdx: i64 = @intCast(j);
                var region = g.calculateRegion(idx, jdx, plant.id) catch continue;
                region.sides = g.calculateSides();
                try regions.append(region);
            }
        }
        g.clearVisits();
        return regions;
    }

    fn calculateRegion(g: *GardenPlots, i: i64, j: i64, id: u8) error{ visited, outofbounds }!Region {
        if (!g.inbounds(i, j)) return error.outofbounds;

        var plant = g.at(i, j);
        if (plant.id != id) return error.outofbounds;

        if (plant.visited) return error.visited;
        plant.visited = true;

        var region = Region{ .id = id, .area = 1, .perimeter = 0 };
        g.regionStep(&region, .{ .i = i, .j = j, .dir = .up });
        g.regionStep(&region, .{ .i = i, .j = j, .dir = .down });
        g.regionStep(&region, .{ .i = i, .j = j, .dir = .right });
        g.regionStep(&region, .{ .i = i, .j = j, .dir = .left });
        return region;
    }

    inline fn regionStep(g: *GardenPlots, reg: *Region, curr: Pos) void {
        const next = move(curr);
        const r = g.calculateRegion(next.i, next.j, reg.id) catch |e| switch (e) {
            error.visited => return,
            error.outofbounds => {
                reg.perimeter += 1;
                const tangent = rotateLeft(curr);
                g.border_map.put(tangent, {}) catch unreachable;
                return;
            },
        };
        reg.area += r.area;
        reg.perimeter += r.perimeter;
    }

    fn calculateSides(g: *GardenPlots) u64 {
        var sides: u64 = 0;
        var it = g.border_map.keyIterator();
        while (it.next()) |border| {
            // Each straight side has exactly one edge without a predecessor.
            if (!g.border_map.contains(moveBack(border.*))) sides += 1;
        }
        g.border_map.clearRetainingCapacity();
        return sides;
    }

    inline fn move(cur: Pos) Pos {
        return switch (cur.dir) {
            .up => .{ .i = cur.i - 1, .j = cur.j, .dir = cur.dir },
            .down => .{ .i = cur.i + 1, .j = cur.j, .dir = cur.dir },
            .left => .{ .i = cur.i, .j = cur.j - 1, .dir = cur.dir },
            .right => .{ .i = cur.i, .j = cur.j + 1, .dir = cur.dir },
        };
    }

    inline fn moveBack(cur: Pos) Pos {
        return switch (cur.dir) {
            .up => .{ .i = cur.i + 1, .j = cur.j, .dir = cur.dir },
            .down => .{ .i = cur.i - 1, .j = cur.j, .dir = cur.dir },
            .left => .{ .i = cur.i, .j = cur.j + 1, .dir = cur.dir },
            .right => .{ .i = cur.i, .j = cur.j - 1, .dir = cur.dir },
        };
    }

    inline fn rotateLeft(cur: Pos) Pos {
        return switch (cur.dir) {
            .up => .{ .i = cur.i, .j = cur.j, .dir = .left },
            .down => .{ .i = cur.i, .j = cur.j, .dir = .right },
            .left => .{ .i = cur.i, .j = cur.j, .dir = .down },
            .right => .{ .i = cur.i, .j = cur.j, .dir = .up },
        };
    }

    inline fn inbounds(garden: GardenPlots, i: i64, j: i64) bool {
        return (0 <= i and i < garden.plot_map.len) and (0 <= j and j < garden.plot_map[0].len);
    }

    inline fn at(garden: GardenPlots, i: i64, j: i64) *Plant {
        return &garden.plot_map[@intCast(i)][@intCast(j)];
    }

    fn clearVisits(garden: *GardenPlots) void {
        for (garden.plot_map) |row| {
            for (row) |*plant| {
                plant.visited = false;
            }
        }
    }
};

fn part1(regions: std.array_list.Managed(Region)) !u64 {
    var price: u64 = 0;
    for (regions.items) |region| price += region.area * region.perimeter;
    return price;
}

fn part2(regions: std.array_list.Managed(Region)) !u64 {
    var price: u64 = 0;
    for (regions.items) |region| price += region.area * region.sides;
    return price;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

fn expectPrices(raw: []const u8, perimeter_price: u64, side_price: u64) !void {
    var garden = try GardenPlots.fromRaw(raw);
    defer garden.deinit();
    const regions = try garden.calculateRegions();
    defer regions.deinit();
    try std.testing.expectEqual(perimeter_price, try part1(regions));
    try std.testing.expectEqual(side_price, try part2(regions));
}

test "sides of a single plot and rectangle" {
    try expectPrices("A\n", 4, 4);
    try expectPrices("AA\n", 12, 8);
}

test "concave corners and a hole" {
    try expectPrices("AA\nAB\n", 28, 22);
    try expectPrices("AAA\nABA\nAAA\n", 132, 68);
}

test "example sides are independent of border iteration order" {
    try expectPrices(@embedFile("example"), 1930, 1206);
}
