const std = @import("std");

const List = std.ArrayList(i32);
const ListList = std.ArrayList(List);
const Map = std.AutoHashMap(i32, i32);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    println("", .{});
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = @embedFile(name);
    const lines = try parseInput(data);
    defer {
        for (lines.items) |line| line.deinit();
        lines.deinit();
    }

    const ans1 = part1(lines);
    const ans2 = try part2(lines);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !ListList {
    var out = ListList.init(gpa.allocator());

    var lines_it = std.mem.splitAny(u8, data, "\n");
    while (lines_it.next()) |line| {
        if (line.len == 0) continue;
        var l = List.init(gpa.allocator());

        var line_it = std.mem.splitAny(u8, line, " ");
        while (line_it.next()) |num| try l.append(try std.fmt.parseInt(i32, num, 10));

        try out.append(l);
    }

    return out;
}

fn part1(list: ListList) u32 {
    var count: u32 = 0;
    outer: for (list.items) |line| {
        const asc = (line.items[0] < line.items[1]);
        var win_it = std.mem.window(i32, line.items, 2, 1);
        while (win_it.next()) |win| {
            const unsafe =
                (@abs(win[0] - win[1]) > 3) or
                (asc and win[0] >= win[1]) or
                (!asc and win[0] <= win[1]);
            if (unsafe) continue :outer;
        }
        count += 1;
    }
    return count;
}

fn part2(list: ListList) !u32 {
    var count: u32 = 0;
    outer: for (list.items) |orig| {
        inner: for (0..orig.items.len) |i| {
            var line = try orig.clone();
            defer line.deinit();

            _ = line.orderedRemove(i);

            const asc = (line.items[0] < line.items[1]);
            var win_it = std.mem.window(i32, line.items, 2, 1);
            while (win_it.next()) |win| {
                const unsafe =
                    (@abs(win[0] - win[1]) > 3) or
                    (asc and win[0] >= win[1]) or
                    (!asc and win[0] <= win[1]);
                if (unsafe) continue :inner;
            }
            count += 1;
            continue :outer;
        }
    }
    return count;
}

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
