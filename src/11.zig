const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var pebbles = try PlutonianPebbles.fromRaw(@embedFile(name));
    defer pebbles.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{try part1(&pebbles)});
    println("part 2: {}", .{try part2(&pebbles)});
}

const Stone = u64;
const BlinkCache = std.AutoHashMap(struct { Stone, u64 }, u64);

const PlutonianPebbles = struct {
    stones: std.ArrayList(Stone),

    fn fromRaw(raw: []const u8) !PlutonianPebbles {
        var stones = std.ArrayList(Stone).init(allocator);

        var it = std.mem.splitAny(u8, raw, " \n");
        while (it.next()) |num| {
            if (num.len == 0) break;
            const stone = try std.fmt.parseInt(Stone, num, 10);
            try stones.append(stone);
        }

        return .{ .stones = stones };
    }

    fn deinit(pebbles: *PlutonianPebbles) void {
        pebbles.stones.deinit();
    }

    fn countStones(pebbles: *PlutonianPebbles, blinks: u64) u64 {
        var cache = BlinkCache.init(allocator);
        defer cache.deinit();

        var ans: u64 = 0;
        for (pebbles.stones.items) |stone| ans += countStonesRec(stone, 0, blinks, &cache);
        return ans;
    }

    fn countStonesRec(stone: Stone, depth: usize, target: usize, cache: *BlinkCache) u64 {
        if (depth == target) return 1;

        const key = .{ stone, depth };
        {
            const maybe = cache.get(.{ stone, depth });
            if (maybe) |val| return val;
        }

        if (stone == 0) {
            const ans = countStonesRec(1, depth + 1, target, cache);
            cache.put(key, ans) catch unreachable;
            return ans;
        }

        const digits = std.math.log10(stone) + 1;
        if (@mod(digits, 2) == 0) {
            const pow = std.math.pow(Stone, 10, @divFloor(digits, 2));
            const left = countStonesRec(@divTrunc(stone, pow), depth + 1, target, cache);
            const right = countStonesRec(@rem(stone, pow), depth + 1, target, cache);
            const ans = left + right;
            cache.put(key, ans) catch unreachable;
            return ans;
        }

        const ans = countStonesRec(stone * 2024, depth + 1, target, cache);
        cache.put(key, ans) catch unreachable;
        return ans;
    }
};

fn part1(pebbles: *PlutonianPebbles) !u64 {
    return pebbles.countStones(25);
}

fn part2(pebbles: *PlutonianPebbles) !u64 {
    return pebbles.countStones(75);
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
