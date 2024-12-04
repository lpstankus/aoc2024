const std = @import("std");

const List = std.ArrayList([]const u8);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer data.deinit();

    const slice = data.items[0 .. data.items.len - 1];
    const ans1 = part1(slice);
    const ans2 = part2(slice);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !List {
    var ls = List.init(gpa.allocator());
    var lines = std.mem.split(u8, data, "\n");
    while (lines.next()) |line| {
        try ls.append(line);
    }
    return ls;
}

fn part1(input: [][]const u8) u32 {
    var count: u32 = 0;
    for (0..input.len) |i| {
        for (0..input[i].len) |j| {
            count += checkXMAS(i, j, input);
        }
    }
    return count;
}

fn part2(input: [][]const u8) u32 {
    var count: u32 = 0;
    for (0..input.len) |i| {
        for (0..input[i].len) |j| {
            count += checkCrossMAS(i, j, input);
        }
    }
    return count;
}

fn checkXMAS(i: usize, j: usize, input: [][]const u8) u32 {
    var count: u32 = 0;
    if (input[i][j] != 'X') return count;

    if (i + 4 <= input.len) {
        const valid =
            (input[i + 1][j] == 'M') and
            (input[i + 2][j] == 'A') and
            (input[i + 3][j] == 'S');
        if (valid) count += 1;
    }

    if (i >= 3) {
        const valid =
            (input[i - 1][j] == 'M') and
            (input[i - 2][j] == 'A') and
            (input[i - 3][j] == 'S');
        if (valid) count += 1;
    }

    if (j + 4 <= input[i].len) {
        const valid =
            (input[i][j + 1] == 'M') and
            (input[i][j + 2] == 'A') and
            (input[i][j + 3] == 'S');
        if (valid) count += 1;
    }

    if (j >= 3) {
        const valid =
            (input[i][j - 1] == 'M') and
            (input[i][j - 2] == 'A') and
            (input[i][j - 3] == 'S');
        if (valid) count += 1;
    }

    if (i + 4 <= input.len and j + 4 <= input[i].len) {
        const valid =
            (input[i + 1][j + 1] == 'M') and
            (input[i + 2][j + 2] == 'A') and
            (input[i + 3][j + 3] == 'S');
        if (valid) count += 1;
    }

    if (i >= 3 and j + 4 <= input[i].len) {
        const valid =
            (input[i - 1][j + 1] == 'M') and
            (input[i - 2][j + 2] == 'A') and
            (input[i - 3][j + 3] == 'S');
        if (valid) count += 1;
    }

    if (i + 4 <= input.len and j >= 3) {
        const valid =
            (input[i + 1][j - 1] == 'M') and
            (input[i + 2][j - 2] == 'A') and
            (input[i + 3][j - 3] == 'S');
        if (valid) count += 1;
    }

    if (i >= 3 and j >= 3) {
        const valid =
            (input[i - 1][j - 1] == 'M') and
            (input[i - 2][j - 2] == 'A') and
            (input[i - 3][j - 3] == 'S');
        if (valid) count += 1;
    }

    return count;
}

fn checkCrossMAS(i: usize, j: usize, input: [][]const u8) u32 {
    if (input[i][j] != 'A') return 0;
    if (1 > i or i > input.len - 2) return 0;
    if (1 > j or j > input[i].len - 2) return 0;

    const diag1 = blk: {
        const nor =
            (input[i - 1][j - 1] == 'M') and
            (input[i + 1][j + 1] == 'S');
        const inv =
            (input[i - 1][j - 1] == 'S') and
            (input[i + 1][j + 1] == 'M');
        break :blk nor or inv;
    };

    const diag2 = blk: {
        const nor =
            (input[i - 1][j + 1] == 'M') and
            (input[i + 1][j - 1] == 'S');
        const inv =
            (input[i - 1][j + 1] == 'S') and
            (input[i + 1][j - 1] == 'M');
        break :blk nor or inv;
    };

    return if (diag1 and diag2) 1 else 0;
}

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
