const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Tower = struct { x: i64, y: i64 };
const TowerList = std.ArrayList(Tower);
const FreqMap = std.AutoHashMap(u8, TowerList);
const Map = struct {
    width: usize,
    height: usize,
    towers: FreqMap,
};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var data = try parseInput(@embedFile(name));
    defer {
        var it = data.towers.valueIterator();
        while (it.next()) |list| list.deinit();
        data.towers.deinit();
    }

    const ans1 = try part1(data);
    const ans2 = try part2(data);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !Map {
    var map = FreqMap.init(allocator);
    var i: usize = 0;
    var j: usize = 0;
    var lines = std.mem.split(u8, data, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        j = 0;
        for (line) |char| {
            if (char != '.') {
                const res = try map.getOrPut(char);
                if (!res.found_existing) res.value_ptr.* = TowerList.init(allocator);
                try res.value_ptr.append(Tower{ .x = @intCast(j), .y = @intCast(i) });
            }
            j += 1;
        }
        i += 1;
    }
    return Map{ .width = j, .height = i, .towers = map };
}

fn part1(map: Map) !u64 {
    var antinodes = try allocator.alloc([]bool, map.height);
    defer allocator.free(antinodes);
    for (0..map.height) |i| {
        antinodes[i] = try allocator.alloc(bool, map.width);
        @memset(antinodes[i], false);
    }
    defer for (antinodes) |line| allocator.free(line);

    var count: u64 = 0;
    var it = map.towers.valueIterator();
    while (it.next()) |towers| {
        for (towers.items, 0..) |a, i| {
            for (towers.items, 0..) |b, j| {
                if (i == j) continue;

                const dx = a.x - b.x;
                const dy = a.y - b.y;

                const aax = a.x + dx;
                const aay = a.y + dy;

                if (inbounds(map, aax, aay)) {
                    const x: usize = @intCast(aax);
                    const y: usize = @intCast(aay);
                    if (!antinodes[y][x]) {
                        antinodes[y][x] = true;
                        count += 1;
                    }
                }

                const bax = b.x - dx;
                const bay = b.y - dy;

                if (inbounds(map, bax, bay)) {
                    const x: usize = @intCast(bax);
                    const y: usize = @intCast(bay);
                    if (!antinodes[y][x]) {
                        antinodes[y][x] = true;
                        count += 1;
                    }
                }
            }
        }
    }

    return count;
}

fn part2(map: Map) !u64 {
    var antinodes = try allocator.alloc([]bool, map.height);
    defer allocator.free(antinodes);
    for (0..map.height) |i| {
        antinodes[i] = try allocator.alloc(bool, map.width);
        @memset(antinodes[i], false);
    }
    defer for (antinodes) |line| allocator.free(line);

    var count: u64 = 0;
    var it = map.towers.valueIterator();
    while (it.next()) |towers| {
        for (towers.items, 0..) |a, i| {
            for (towers.items, 0..) |b, j| {
                if (i == j) continue;

                const dx = a.x - b.x;
                const dy = a.y - b.y;

                var aax = a.x;
                var aay = a.y;
                while (inbounds(map, aax, aay)) {
                    const x: usize = @intCast(aax);
                    const y: usize = @intCast(aay);
                    if (!antinodes[y][x]) {
                        antinodes[y][x] = true;
                        count += 1;
                    }
                    aax += dx;
                    aay += dy;
                }

                var bax = b.x;
                var bay = b.y;
                while (inbounds(map, bax, bay)) {
                    const x: usize = @intCast(bax);
                    const y: usize = @intCast(bay);
                    if (!antinodes[y][x]) {
                        antinodes[y][x] = true;
                        count += 1;
                    }
                    bax -= dx;
                    bay -= dy;
                }
            }
        }
    }

    return count;
}

inline fn inbounds(map: Map, x: i64, y: i64) bool {
    const in_x = 0 <= x and x < map.width;
    const in_y = 0 <= y and y < map.height;
    return in_x and in_y;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
