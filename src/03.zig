const std = @import("std");

pub fn main() !void {
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = @embedFile(name);

    const ans1 = part1(data);
    const ans2 = part2(data);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseMul(input: []const u8) ?struct { result: u32, stride: u32 } {
    var i: u32 = 0;

    var len1: u32 = 0;
    var arg1 = [_]u8{0} ** 3;
    var len2: u32 = 0;
    var arg2 = [_]u8{0} ** 3;

    if (input.len < 3) return null;
    if (!std.mem.eql(u8, input[i .. i + 3], "mul")) return null;
    i += 3;

    if (input[i] != '(') return null;
    i += 1;

    for (input[i..], 0..) |c, ln| {
        if (ln > 3) return null;
        if (!std.ascii.isDigit(c)) {
            if (len1 == 0) return null;
            break;
        }
        arg1[len1] = c;
        len1 += 1;
        i += 1;
    }

    if (input[i] != ',') return null;
    i += 1;

    for (input[i..], 0..) |c, ln| {
        if (ln > 3) return null;
        if (!std.ascii.isDigit(c)) {
            if (len1 == 0) return null;
            break;
        }
        arg2[len2] = c;
        len2 += 1;
        i += 1;
    }

    if (input[i] != ')') return null;
    i += 1;

    const n1 = std.fmt.parseInt(u32, arg1[0..len1], 10) catch return null;
    const n2 = std.fmt.parseInt(u32, arg2[0..len2], 10) catch return null;

    return .{ .result = n1 * n2, .stride = i };
}

fn parseDoDont(input: []const u8) ?struct { do: bool, stride: u32 } {
    if (input.len < 4) return null;
    if (std.mem.eql(u8, input[0..4], "do()")) {
        return .{ .do = true, .stride = 4 };
    }
    if (input.len < 7) return null;
    if (std.mem.eql(u8, input[0..7], "don't()")) {
        return .{ .do = false, .stride = 7 };
    }
    return null;
}

fn part1(input: []const u8) u32 {
    var sum: u32 = 0;
    var i: u32 = 0;
    while (i < input.len) {
        const res = parseMul(input[i..]) orelse {
            i += 1;
            continue;
        };
        sum += res.result;
        i += res.stride;
    }
    return sum;
}

fn part2(input: []const u8) u32 {
    var sum: u32 = 0;
    var i: u32 = 0;
    var do = true;
    while (i < input.len) {
        const maybe_res = parseDoDont(input[i..]);
        if (maybe_res) |res| {
            do = res.do;
            i += res.stride;
            continue;
        }

        if (do) blk: {
            const res = parseMul(input[i..]) orelse break :blk;
            sum += res.result;
            i += res.stride;
            continue;
        }

        i += 1;
    }
    return sum;
}

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
