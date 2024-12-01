const std = @import("std");

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

const List = std.ArrayList(i32);
const Map = std.AutoHashMap(i32, i32);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const example = @embedFile("example");
    const input = @embedFile("input");

    var list1 = List.init(gpa.allocator());
    var list2 = List.init(gpa.allocator());
    defer list1.deinit();
    defer list2.deinit();

    {
        try parseInput(&list1, &list2, example);

        const ans1 = part1(list1, list2);
        const ans2 = try part2(list1, list2, gpa.allocator());

        println(">> Examples", .{});
        println("part 1: {}", .{ans1});
        println("part 2: {}", .{ans2});
    }

    list1.clearAndFree();
    list2.clearAndFree();

    {
        try parseInput(&list1, &list2, input);

        const ans1 = part1(list1, list2);
        const ans2 = try part2(list1, list2, gpa.allocator());

        println(">> Input", .{});
        println("part 1: {}", .{ans1});
        println("part 2: {}", .{ans2});
    }
}

fn parseInput(list1: *List, list2: *List, data: []const u8) !void {
    var i: usize = 0;
    var it = std.mem.splitAny(u8, data, " \n");
    while (it.next()) |item| {
        if (item.len == 0) continue;
        const n = try std.fmt.parseInt(i32, item, 10);
        if (i % 2 == 0) try list1.append(n) else try list2.append(n);
        i += 1;
    }
}

fn part1(list1: List, list2: List) u32 {
    std.mem.sort(i32, list1.items, {}, comptime std.sort.asc(i32));
    std.mem.sort(i32, list2.items, {}, comptime std.sort.asc(i32));

    std.debug.assert(list1.items.len == list2.items.len);

    var sum: u32 = 0;
    for (list1.items, list2.items) |item1, item2| sum += @abs(item1 - item2);
    return sum;
}

fn part2(list1: List, list2: List, alloc: std.mem.Allocator) !u32 {
    var map = Map.init(alloc);
    defer map.deinit();

    for (list2.items) |item| {
        const val = map.get(item) orelse 0;
        try map.put(item, val + 1);
    }

    var sum: u32 = 0;
    for (list1.items) |item| {
        const val = map.get(item) orelse 0;
        sum += @intCast(item * val);
    }
    return sum;
}
