const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Calibration = std.ArrayList(Equation);
const Equation = struct {
    ans: u64,
    elements: []u64,
};

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer {
        for (data.items) |eq| allocator.free(eq.elements);
        data.deinit();
    }

    const ans1 = part1(data);
    const ans2 = part2(data);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !Calibration {
    var calib = Calibration.init(allocator);
    var lines = std.mem.split(u8, data, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var eq: Equation = undefined;
        var args = std.mem.splitAny(u8, line, ": ");
        eq.ans = try std.fmt.parseInt(u64, args.next().?, 10);

        var temp = std.ArrayList(u64).init(allocator);
        defer temp.deinit();

        while (args.next()) |arg| {
            if (arg.len == 0) continue;
            try temp.append(try std.fmt.parseInt(u64, arg, 10));
        }
        eq.elements = try allocator.dupe(u64, temp.items);
        try calib.append(eq);
    }
    return calib;
}

fn part1(calib: Calibration) u64 {
    var sum: u64 = 0;
    for (calib.items) |eq| {
        if (checkPossibility(eq, false)) sum += eq.ans;
    }
    return sum;
}

fn part2(calib: Calibration) u64 {
    var sum: u64 = 0;
    for (calib.items) |eq| {
        if (checkPossibility(eq, true)) sum += eq.ans;
    }
    return sum;
}

inline fn checkPossibility(eq: Equation, concat: bool) bool {
    return checkPossRec(eq.elements, 0, eq.ans, concat);
}

fn checkPossRec(elements: []u64, cur: u64, ans: u64, concat: bool) bool {
    if (elements.len == 0) return cur == ans;
    const solvable =
        checkPossRec(elements[1..], cur + elements[0], ans, concat) or
        checkPossRec(elements[1..], cur * elements[0], ans, concat) or
        (concat and checkPossRec(elements[1..], concatNumbers(cur, elements[0]), ans, concat));
    return solvable;
}

fn concatNumbers(l: u64, r: u64) u64 {
    const exp = std.math.log10(r) + 1;
    const base = std.math.pow(u64, 10, exp);
    return l * base + r;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
