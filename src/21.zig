const std = @import("std");

const Vec2 = struct { i: usize = 0, j: usize = 0 };
const MoveButton = enum { right, left, up, down, activate };
const MoveSeq = std.ArrayList(MoveButton);
const Code = struct { btn: []u8, num: usize };

const Cache = std.AutoHashMap(struct { cur: Vec2, tar: Vec2, depth: usize }, u64);
var cache: Cache = undefined;

const A = 10;
const INF = std.math.maxInt(usize);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();

    cache = Cache.init(allocator);
    defer cache.deinit();

    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var codes = try parseInput(@embedFile(name));
    defer {
        for (codes.items) |code| allocator.free(code.btn);
        codes.deinit();
    }

    var part1: usize = 0;
    for (codes.items) |code| {
        const ret = try minPresses(code.btn, 2);
        part1 += ret * code.num;
    }

    var part2: usize = 0;
    for (codes.items) |code| {
        const ret = try minPresses(code.btn, 25);
        part2 += ret * code.num;
    }

    println(">> {s}:", .{name});
    println("part 1: {}", .{part1});
    println("part 2: {}", .{part2});
}

fn parseInput(raw: []const u8) !std.ArrayList(Code) {
    var codes = std.ArrayList(Code).init(allocator);
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const code = try allocator.alloc(u8, 4);
        for (line, 0..) |c, i| {
            if (i < 3) {
                code[i] = c - '0';
                continue;
            }
            std.debug.assert(c == 'A');
            code[i] = A;
        }
        try codes.append(.{ .btn = code, .num = try std.fmt.parseInt(usize, line[0..3], 10) });
    }
    return codes;
}

fn minPresses(code: []const u8, depth: usize) !usize {
    var btns = try MoveSeq.initCapacity(allocator, 256);
    defer btns.deinit();

    var ans: usize = 0;
    var cur = Vec2{ .i = 3, .j = 2 };
    for (code) |tar_btn| {
        const tar = directTranslatePos(tar_btn);

        btns.clearRetainingCapacity();
        if (cur.i == 3 and tar.j == 0) {
            cur = try moveU(cur, tar, &btns);
            cur = try moveL(cur, tar, &btns);
        } else if (cur.j == 0 and tar.i == 3) {
            cur = try moveR(cur, tar, &btns);
            cur = try moveD(cur, tar, &btns);
        } else {
            cur = try moveL(cur, tar, &btns);
            cur = try moveU(cur, tar, &btns);
            cur = try moveD(cur, tar, &btns);
            cur = try moveR(cur, tar, &btns);
        }
        try btns.append(.activate);

        ans += try indirectPress(btns, depth);
    }
    return ans;
}

fn indirectPress(input_btns: MoveSeq, depth: usize) !usize {
    if (depth == 0) return input_btns.items.len;

    var btns = try MoveSeq.initCapacity(allocator, 256);
    defer btns.deinit();

    var ans: usize = 0;
    var cur = Vec2{ .i = 0, .j = 2 };
    for (input_btns.items) |tar_btn| {
        const org = cur;
        const tar = indirectTranslatePos(tar_btn);

        if (cache.get(.{ .cur = org, .tar = tar, .depth = depth })) |val| {
            ans += val;
            cur = tar;
            continue;
        }

        btns.clearRetainingCapacity();
        if (cur.i == 0 and tar.j == 0) {
            cur = try moveD(cur, tar, &btns);
            cur = try moveL(cur, tar, &btns);
        } else if (cur.j == 0 and tar.i == 0) {
            cur = try moveR(cur, tar, &btns);
            cur = try moveU(cur, tar, &btns);
        } else {
            cur = try moveL(cur, tar, &btns);
            cur = try moveU(cur, tar, &btns);
            cur = try moveD(cur, tar, &btns);
            cur = try moveR(cur, tar, &btns);
        }
        try btns.append(.activate);

        const ret = try indirectPress(btns, depth - 1);
        try cache.put(.{ .cur = org, .tar = tar, .depth = depth }, ret);
        ans += ret;
    }
    return ans;
}

inline fn directTranslatePos(val: u8) Vec2 {
    const i = if (val == 0 or val == A) 3 else 2 - @divFloor(val - 1, 3);
    const j = switch (val) {
        0 => 1,
        A => 2,
        else => @mod(val - 1, 3),
    };
    return .{ .i = i, .j = j };
}

inline fn indirectTranslatePos(btn: MoveButton) Vec2 {
    return switch (btn) {
        .up => .{ .i = 0, .j = 1 },
        .activate => .{ .i = 0, .j = 2 },
        .left => .{ .i = 1, .j = 0 },
        .down => .{ .i = 1, .j = 1 },
        .right => .{ .i = 1, .j = 2 },
    };
}

inline fn moveR(cur: Vec2, tar: Vec2, btns: anytype) !Vec2 {
    return if (cur.j < tar.j) blk: {
        for (0..(tar.j - cur.j)) |_| try btns.append(.right);
        break :blk .{ .i = cur.i, .j = tar.j };
    } else cur;
}

inline fn moveL(cur: Vec2, tar: Vec2, btns: anytype) !Vec2 {
    return if (cur.j > tar.j) blk: {
        for (0..(cur.j - tar.j)) |_| try btns.append(.left);
        break :blk .{ .i = cur.i, .j = tar.j };
    } else cur;
}

inline fn moveU(cur: Vec2, tar: Vec2, btns: anytype) !Vec2 {
    return if (cur.i > tar.i) blk: {
        for (0..(cur.i - tar.i)) |_| try btns.append(.up);
        break :blk .{ .i = tar.i, .j = cur.j };
    } else cur;
}

inline fn moveD(cur: Vec2, tar: Vec2, btns: anytype) !Vec2 {
    return if (cur.i < tar.i) blk: {
        for (0..(tar.i - cur.i)) |_| try btns.append(.down);
        break :blk .{ .i = tar.i, .j = cur.j };
    } else cur;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
