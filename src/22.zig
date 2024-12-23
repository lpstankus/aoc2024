const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

var cache: std.AutoHashMap(u32, usize) = undefined;
var visited: std.AutoHashMap(u32, void) = undefined;

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var seeds = try parseInput(@embedFile(name));
    defer seeds.deinit();

    cache = std.AutoHashMap(u32, usize).init(allocator);
    defer cache.deinit();

    visited = std.AutoHashMap(u32, void).init(allocator);
    defer visited.deinit();

    var part1: usize = 0;
    for (seeds.items) |seed| {
        part1 += step(seed, 2000);
    }

    var part2: usize = 0;
    var it = cache.iterator();
    while (it.next()) |el| part2 = @max(part2, el.value_ptr.*);

    println(">> {s}:", .{name});
    println("part 1: {}", .{part1});
    println("part 2: {}", .{part2});
}

fn parseInput(raw: []const u8) !std.ArrayList(usize) {
    var seeds = std.ArrayList(usize).init(allocator);
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try seeds.append(try std.fmt.parseInt(usize, line, 10));
    }
    return seeds;
}

inline fn pack(prevs: [5]i8) u32 {
    var key: u32 = 0;
    for (0..4) |i| {
        const diff = prevs[i + 1] - prevs[i];
        key |= @as(u32, @intCast(@as(u8, @bitCast(diff)))) << (8 * @as(u5, @intCast(i)));
    }
    return key;
}

const MODULO: usize = 16777216;

inline fn step(seed: usize, steps: usize) u64 {
    var cur = seed;
    var prevs = [_]i8{0} ** 5;
    for (0..@min(4, steps)) |i| {
        cur = @mod(cur ^ (cur << 6), MODULO);
        cur = @mod(cur ^ (cur >> 5), MODULO);
        cur = @mod(cur ^ (cur << 11), MODULO);
        prevs[i + 1] = @intCast(@mod(cur, 10));
    }

    visited.clearRetainingCapacity();

    for (4..steps) |_| {
        cur = @mod(cur ^ (cur << 6), MODULO);
        cur = @mod(cur ^ (cur >> 5), MODULO);
        cur = @mod(cur ^ (cur << 11), MODULO);

        inline for (0..4) |i| prevs[i] = prevs[i + 1];
        prevs[4] = @intCast(@mod(cur, 10));

        const key = pack(prevs);
        if (!visited.contains(key)) {
            visited.put(key, {}) catch unreachable;

            const ret = cache.getOrPut(key) catch unreachable;
            const price: usize = @intCast(prevs[4]);
            ret.value_ptr.* = if (ret.found_existing) ret.value_ptr.* + price else price;
        }
    }

    return cur;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
