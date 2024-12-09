const std = @import("std");

const verbose = false;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer allocator.free(data);

    println(">> {s}:", .{name});
    println("part 1: {}", .{try part1(data)});
    println("part 2: {}", .{try part2(data)});
}

fn parseInput(data: []const u8) ![]const i64 {
    var list = std.ArrayList(i64).init(allocator);
    defer list.deinit();

    var id: i64 = 0;
    for (data, 0..) |char, i| {
        if (char < '0') break;

        var el: i64 = -1;
        if (i % 2 == 0) {
            el = id;
            id += 1;
        }
        for (0..(char - '0')) |_| try list.append(el);
    }

    return try allocator.dupe(i64, list.items);
}

fn part1(input: []const i64) !u64 {
    const data = try allocator.dupe(i64, input);
    defer allocator.free(data);

    if (verbose) printDisk(data);

    var l: usize = 0;
    var r: usize = data.len - 1;
    while (l < r) {
        if (data[l] >= 0) {
            l += 1;
            continue;
        }
        if (data[r] < 0) {
            r -= 1;
            continue;
        }
        data[l] = data[r];
        data[r] = -1;

        if (verbose) printDisk(data);
    }
    return checksum(data);
}

fn part2(input: []const i64) !u64 {
    const data = try allocator.dupe(i64, input);
    defer allocator.free(data);

    if (verbose) printDisk(data);

    var r: usize = data.len - 1;
    while (data[r] != 0) : (r -= 1) {
        if (data[r - 1] == data[r] or data[r] < 0) continue;

        var blockLen: usize = 0;
        for (data[r..]) |el| {
            if (data[r] != el) break;
            blockLen += 1;
        }

        var l: usize = 0;
        while (l < r) : (l += 1) {
            if (data[l] >= 0) continue;

            var freeLen: usize = 0;
            for (data[l..]) |el| {
                if (data[l] != el) break;
                freeLen += 1;
            }

            if (freeLen < blockLen) {
                l += freeLen - 1;
                continue;
            }

            const blockId = data[r];
            for (0..blockLen) |i| {
                data[l + i] = blockId;
                data[r + i] = -1;
            }

            if (verbose) printDisk(data);

            break;
        }
    }

    return checksum(data);
}

fn checksum(data: []i64) u64 {
    var sum: u64 = 0;
    for (data, 0..) |el, i| {
        if (el < 0) continue;
        sum += i * @as(usize, @intCast(el));
    }
    return sum;
}

fn printDisk(data: []i64) void {
    for (data) |item| {
        if (item < 0) {
            print(".", .{});
            continue;
        }
        print("{}", .{item});
    }
    println("", .{});
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
