const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Data = struct { patterns: [][]u8, designs: [][]u8 };
const Cache = std.StringHashMap(u64);

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer {
        for (data.patterns) |pat| allocator.free(pat);
        allocator.free(data.patterns);
        for (data.designs) |des| allocator.free(des);
        allocator.free(data.designs);
    }

    var cache = Cache.init(allocator);
    defer cache.deinit();

    var count: u64 = 0;
    var unique: u64 = 0;
    for (data.designs) |des| {
        const ret = countPossible(data.patterns, des, &cache) catch continue;
        if (ret == 0) continue;
        count += ret;
        unique += 1;
    }

    println(">> {s}:", .{name});
    println("part 1: {}", .{unique});
    println("part 2: {}", .{count});
}

fn parseInput(raw: []const u8) !Data {
    var patterns = std.ArrayList([]u8).init(allocator);
    defer patterns.deinit();

    var lines = std.mem.splitScalar(u8, raw, '\n');
    const raw_pats = lines.next() orelse unreachable;

    var pats_it = std.mem.splitAny(u8, raw_pats, ", ");
    while (pats_it.next()) |pat| {
        if (pat.len == 0) continue;
        try patterns.append(try allocator.dupe(u8, pat));
    }

    var designs = std.ArrayList([]u8).init(allocator);
    defer designs.deinit();

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        try designs.append(try allocator.dupe(u8, line));
    }

    return .{
        .patterns = try allocator.dupe([]u8, patterns.items),
        .designs = try allocator.dupe([]u8, designs.items),
    };
}

fn countPossible(patterns: [][]u8, design: []u8, cache: *Cache) !u64 {
    if (design.len == 0) return 1;
    if (cache.get(design)) |count| return count;

    var ans: u64 = 0;
    for (patterns) |pat| {
        if (!std.mem.startsWith(u8, design, pat)) continue;
        ans += countPossible(patterns, design[pat.len..], cache) catch continue;
    }
    try cache.put(design, ans);
    return ans;
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
