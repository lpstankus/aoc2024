const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Update = std.ArrayList(u32);
const UpdateList = std.ArrayList(Update);

const IdMap = std.AutoHashMap(u32, void);
const PageMap = std.AutoHashMap(u32, IdMap);

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer {
        var pages = data.pages;
        defer pages.deinit();
        var it = pages.valueIterator();
        while (it.next()) |value| value.deinit();

        var updates = data.updates;
        defer updates.deinit();
        for (updates.items) |value| value.deinit();
    }

    const ans1 = part1(data.pages, data.updates);
    const ans2 = part2(data.pages, data.updates);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !struct { pages: PageMap, updates: UpdateList } {
    var pages = PageMap.init(gpa.allocator());
    var lines = std.mem.split(u8, data, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) break;

        var args = std.mem.split(u8, line, "|");
        const par = try std.fmt.parseInt(u32, args.next() orelse "", 10);
        const chi = try std.fmt.parseInt(u32, args.next() orelse "", 10);

        if (pages.getPtr(par)) |page| {
            try page.put(chi, {});
        } else {
            var children = IdMap.init(gpa.allocator());
            try children.put(chi, {});
            try pages.put(par, children);
        }
    }

    var updates = UpdateList.init(gpa.allocator());
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var update = Update.init(gpa.allocator());
        var it = std.mem.split(u8, line, ",");
        while (it.next()) |id| {
            try update.append(try std.fmt.parseInt(u32, id, 10));
        }
        try updates.append(update);
    }

    return .{ .pages = pages, .updates = updates };
}

fn part1(pages: PageMap, updates: UpdateList) u32 {
    var ans: u32 = 0;
    for (updates.items) |update| {
        if (!isOrdered(pages, update)) continue;
        const idx = update.items.len / 2;
        ans += update.items[idx];
    }
    return ans;
}

fn part2(pages: PageMap, updates: UpdateList) u32 {
    var ans: u32 = 0;
    for (updates.items) |update| {
        if (isOrdered(pages, update)) continue;

        const up = update.items;
        for (0..update.items.len) |i| {
            var j: usize = i + 1;
            while (j < up.len) : (j += 1) {
                if (isDep(pages, up[j], up[i])) {
                    std.mem.swap(u32, &up[i], &up[j]);
                    j = i;
                }
            }
        }

        const idx = update.items.len / 2;
        ans += update.items[idx];
    }
    return ans;
}

fn isOrdered(pages: PageMap, update: Update) bool {
    for (0..update.items.len) |i| {
        for (update.items[0..i]) |tst| {
            if (isDep(pages, update.items[i], tst)) return false;
        }
    }
    return true;
}

fn isDep(pages: PageMap, cur: u32, tar: u32) bool {
    const cur_page = pages.get(cur) orelse return false;
    if (cur_page.contains(tar)) return true;
    return false;
}

fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
