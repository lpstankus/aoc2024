const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var guide = try HikingGuide.fromRaw(@embedFile(name));
    defer guide.deinit();

    const ans = try guide.summary();
    println(">> {s}:", .{name});
    println("part 1: {}", .{ans.unique});
    println("part 2: {}", .{ans.total});
}

const Pos = struct { x: i64, y: i64, lvl: u8 = 0 };
const Hike = struct { orig: Pos, dest: Pos };
const HikeCounts = std.AutoHashMap(Hike, u64);
const HikingGuide = struct {
    width: usize,
    height: usize,
    trailheads: std.ArrayList(Pos),
    topo: [][]u8,

    fn fromRaw(raw: []const u8) !HikingGuide {
        var list = std.ArrayList([]u8).init(allocator);
        defer list.deinit();

        var heads = std.ArrayList(Pos).init(allocator);

        var width: usize = 0;
        var height: usize = 0;

        var i: i64 = 0;
        var lines = std.mem.split(u8, raw, "\n");
        while (lines.next()) |line| {
            if (line.len == 0) break;
            width = line.len;

            var j: i64 = 0;
            const topo = try allocator.dupe(u8, line);
            for (topo) |*val| {
                val.* = val.* - '0';
                if (val.* == 0) try heads.append(.{ .x = j, .y = i });
                j += 1;
            }
            try list.append(topo);
            i += 1;
        }
        height = @intCast(i);

        const topo = try allocator.dupe([]u8, list.items);
        return .{ .width = width, .height = height, .trailheads = heads, .topo = topo };
    }

    fn deinit(guide: *HikingGuide) void {
        for (guide.topo) |row| allocator.free(row);
        allocator.free(guide.topo);
        guide.trailheads.deinit();
    }

    fn summary(guide: HikingGuide) !struct { unique: u64, total: u64 } {
        var peaks = try guide.reachablePeaks();
        defer peaks.deinit();

        var unique: u64 = 0;
        var total: u64 = 0;
        var it = peaks.valueIterator();
        while (it.next()) |count| {
            unique += 1;
            total += count.*;
        }
        return .{ .unique = unique, .total = total };
    }

    fn reachablePeaks(guide: HikingGuide) !HikeCounts {
        var peaks = HikeCounts.init(allocator);
        for (guide.trailheads.items) |head| {
            var q = Queue.init();
            defer q.deinit();

            try q.append(head);
            while (q.pop()) |cur| {
                if (cur.lvl != guide.getTopo(cur)) continue;
                if (cur.lvl == 9) {
                    const res = try peaks.getOrPut(.{ .orig = head, .dest = cur });
                    res.value_ptr.* = if (res.found_existing) res.value_ptr.* + 1 else 1;
                    continue;
                }
                try q.append(.{ .x = cur.x + 1, .y = cur.y, .lvl = cur.lvl + 1 });
                try q.append(.{ .x = cur.x, .y = cur.y + 1, .lvl = cur.lvl + 1 });
                try q.append(.{ .x = cur.x - 1, .y = cur.y, .lvl = cur.lvl + 1 });
                try q.append(.{ .x = cur.x, .y = cur.y - 1, .lvl = cur.lvl + 1 });
            }
        }
        return peaks;
    }

    inline fn getTopo(guide: HikingGuide, pos: Pos) ?u8 {
        const x_bounds = 0 <= pos.x and pos.x < guide.width;
        const y_bounds = 0 <= pos.y and pos.y < guide.height;
        if (!x_bounds or !y_bounds) return null;
        return guide.topo[@intCast(pos.y)][@intCast(pos.x)];
    }
};

const Queue = struct {
    list: std.DoublyLinkedList(Pos),
    arena: std.heap.ArenaAllocator,

    inline fn init() Queue {
        return .{ .list = .{}, .arena = std.heap.ArenaAllocator.init(allocator) };
    }

    inline fn deinit(q: *Queue) void {
        q.arena.deinit();
    }

    inline fn append(q: *Queue, p: Pos) !void {
        var nd = try q.arena.allocator().create(@TypeOf(q.list).Node);
        nd.data = p;
        q.list.append(nd);
    }

    inline fn pop(q: *Queue) ?Pos {
        return if (q.list.pop()) |nd| nd.data else null;
    }
};

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
