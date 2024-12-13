const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var arcade = try parseInput(@embedFile(name));
    defer arcade.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{try part1(arcade)});
    println("part 2: {}", .{try part2(&arcade)});
}

const Target = struct { x: i64, y: i64 };
const Button = struct { cost: i64, x: i64, y: i64 };
const Machine = struct { a: Button, b: Button, t: Target };
const Arcade = std.ArrayList(Machine);

fn part1(arcade: Arcade) !u64 {
    return requiredTokens(arcade);
}

fn part2(arcade: *Arcade) !u64 {
    adjustConversionError(arcade);
    return requiredTokens(arcade.*);
}

fn parseInput(raw: []const u8) !Arcade {
    var machines = Arcade.init(allocator);

    var blocks = std.mem.splitSequence(u8, raw, "\n\n");
    while (blocks.next()) |machine| {
        var lines = std.mem.splitAny(u8, machine, "\n");

        const a = blk: {
            const str = lines.next() orelse unreachable;
            var it = std.mem.splitAny(u8, str, "+,");
            _ = it.next();
            const x = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            _ = it.next();
            const y = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            break :blk Button{ .cost = 3, .x = x, .y = y };
        };

        const b = blk: {
            const str = lines.next() orelse unreachable;
            var it = std.mem.splitAny(u8, str, "+,");
            _ = it.next();
            const x = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            _ = it.next();
            const y = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            break :blk Button{ .cost = 1, .x = x, .y = y };
        };

        const t = blk: {
            const t = lines.next() orelse unreachable;
            var it = std.mem.splitAny(u8, t, "=,");
            _ = it.next();
            const x = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            _ = it.next();
            const y = try std.fmt.parseInt(i64, it.next() orelse unreachable, 10);
            break :blk Target{ .x = x, .y = y };
        };

        try machines.append(.{ .a = a, .b = b, .t = t });
    }
    return machines;
}

fn adjustConversionError(arcade: *Arcade) void {
    for (arcade.items) |*machine| {
        machine.t.x += 10000000000000;
        machine.t.y += 10000000000000;
    }
}

fn requiredTokens(arcade: Arcade) u64 {
    var ans: u64 = 0;
    for (arcade.items) |m| {
        // cramer's rule
        if (m.b.y * m.a.x == m.b.x * m.a.y) continue;

        const a_count = std.math.divExact(
            i64,
            m.b.y * m.t.x - m.b.x * m.t.y,
            m.a.x * m.b.y - m.a.y * m.b.x,
        ) catch continue;

        const b_count = std.math.divExact(
            i64,
            m.a.x * m.t.y - m.a.y * m.t.x,
            m.a.x * m.b.y - m.a.y * m.b.x,
        ) catch continue;

        ans += @intCast(m.a.cost * a_count + m.b.cost * b_count);
    }
    return ans;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
