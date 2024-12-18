const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const example = comptime std.mem.eql(u8, name, "example");
    var map = try Map(example).fromRaw(@embedFile(name));
    defer map.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{try map.findExit()});
    println("part 2: {}", .{map.findCutOut()});
}

const Vec2 = struct { x: i64 = 0, y: i64 = 0 };
const Cell = enum { corrupt, free };

fn Map(comptime example: bool) type {
    return struct {
        cells: [SIZE][SIZE]Cell = [_][SIZE]Cell{[_]Cell{.free} ** SIZE} ** SIZE,
        bytes: std.ArrayList(Vec2),

        const SIZE = if (example) 7 else 71;
        const INITIAL_ELAPSE = if (example) 12 else 1024;

        const Self = @This();

        fn fromRaw(raw: []const u8) !Self {
            var map = Self{ .bytes = std.ArrayList(Vec2).init(allocator) };
            var lines = std.mem.splitScalar(u8, raw, '\n');
            while (lines.next()) |line| {
                if (line.len == 0) break;
                var it = std.mem.splitScalar(u8, line, ',');
                const x = try std.fmt.parseInt(u8, it.next() orelse unreachable, 10);
                const y = try std.fmt.parseInt(u8, it.next() orelse unreachable, 10);
                if (map.bytes.items.len < INITIAL_ELAPSE) map.cells[y][x] = .corrupt;
                try map.bytes.append(.{ .x = x, .y = y });
            }
            return map;
        }

        fn deinit(map: *Self) void {
            map.bytes.deinit();
        }

        const Key = struct { Vec2, u64 };
        fn compareFn(_: void, l: Key, r: Key) std.math.Order {
            if (l[1] < r[1]) return .lt;
            if (l[1] > r[1]) return .gt;
            return .eq;
        }

        fn findExit(map: Self) !u64 {
            var pq = std.PriorityQueue(struct { Vec2, u64 }, void, compareFn).init(allocator, {});
            defer pq.deinit();

            var visited = std.AutoHashMap(Vec2, void).init(allocator);
            defer visited.deinit();

            try pq.add(.{ .{}, 0 });
            while (pq.removeOrNull()) |cur| {
                const cell = map.get(cur[0]) catch continue;
                if (cell == .corrupt) continue;

                if (visited.contains(cur[0])) continue;
                try visited.put(cur[0], {});

                if (cur[0].x == SIZE - 1 and cur[0].y == SIZE - 1) return cur[1];

                inline for ([_]Vec2{ .{ .x = -1 }, .{ .x = 1 }, .{ .y = -1 }, .{ .y = 1 } }) |dir| {
                    try pq.add(.{ .{ .x = cur[0].x + dir.x, .y = cur[0].y + dir.y }, cur[1] + 1 });
                }
            }
            return error.PathNotFound;
        }

        fn findCutOut(map: *Self) struct { i64, i64 } {
            var l: usize = 0;
            var r: usize = map.bytes.items.len;
            while (l < r) {
                const mid = l + (r - l) / 2;
                for (map.bytes.items[0 .. mid + 1]) |byte| {
                    map.cells[@intCast(byte.y)][@intCast(byte.x)] = .corrupt;
                }
                defer for (map.bytes.items[0 .. mid + 1]) |byte| {
                    map.cells[@intCast(byte.y)][@intCast(byte.x)] = .free;
                };

                _ = map.findExit() catch {
                    r = mid;
                    continue;
                };
                l = mid + 1;
                continue;
            }
            const byte = map.bytes.items[r];
            return .{ byte.x, byte.y };
        }

        fn get(map: Self, pos: Vec2) !Cell {
            const x_bounds = 0 <= pos.x and pos.x < SIZE;
            const y_bounds = 0 <= pos.y and pos.y < SIZE;
            if (!x_bounds or !y_bounds) return .corrupt;
            return map.cells[@intCast(pos.y)][@intCast(pos.x)];
        }
    };
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
