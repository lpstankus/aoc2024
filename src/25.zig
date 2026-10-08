const std = @import("std");

var gpa = std.heap.DebugAllocator(.{}){};
var allocator = gpa.allocator();

const Pins = [5]u8;

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer data.locks.deinit();
    defer data.keys.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{part1(data.locks, data.keys)});
}

fn parseInput(raw: []const u8) !struct { locks: std.array_list.Managed(Pins), keys: std.array_list.Managed(Pins) } {
    var locks = std.array_list.Managed(Pins).init(allocator);
    var keys = std.array_list.Managed(Pins).init(allocator);

    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) break;

        if (std.mem.eql(u8, line, "#####")) {
            var cur: u8 = 0;
            var pins: [5]u8 = @splat(0xFF);

            var lock = lines.next().?;
            while (lock.len != 0) : (lock = lines.next().?) {
                for (lock, 0..) |char, i| {
                    if (char == '.') pins[i] = @min(pins[i], cur);
                }
                cur += 1;
            }

            try locks.append(pins);
            continue;
        }

        if (std.mem.eql(u8, line, ".....")) {
            var cur: u8 = 4;
            var pins: [5]u8 = @splat(5);

            var lock = lines.next().?;
            while (lock.len != 0) : (lock = lines.next().?) {
                for (lock, 0..) |char, i| {
                    if (char == '.') pins[i] = @min(pins[i], cur);
                }
                cur -|= 1;
            }

            try keys.append(pins);
            continue;
        }

        unreachable;
    }

    return .{ .keys = keys, .locks = locks };
}

fn part1(locks: std.array_list.Managed(Pins), keys: std.array_list.Managed(Pins)) usize {
    var ans: usize = 0;
    for (locks.items) |lock| {
        outer: for (keys.items) |key| {
            inline for (0..5) |i| {
                if (lock[i] + key[i] > 5) continue :outer;
            }
            ans += 1;
        }
    }
    return ans;
}

const print = std.debug.print;
inline fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
