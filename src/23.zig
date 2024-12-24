const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Id = [2]u8;
const CompSet = std.AutoHashMap(Id, void);
const Computers = std.AutoHashMap(Id, CompSet);

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var pcs = try parseInput(@embedFile(name));
    defer {
        var it = pcs.iterator();
        while (it.next()) |el| el.value_ptr.deinit();
        pcs.deinit();
    }

    const part1 = try countParties(pcs);
    const part2 = try largestParty(pcs);
    defer allocator.free(part2);

    println(">> {s}:", .{name});
    println("part 1: {}", .{part1});
    println("part 2: {s}", .{part2});
}

fn parseInput(raw: []const u8) !Computers {
    var pcs = Computers.init(allocator);
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const a = [_]u8{ line[0], line[1] };
        const b = [_]u8{ line[3], line[4] };
        {
            const ret = try pcs.getOrPut(a);
            if (!ret.found_existing) ret.value_ptr.* = CompSet.init(allocator);
            try ret.value_ptr.put(b, {});
        }
        {
            const ret = try pcs.getOrPut(b);
            if (!ret.found_existing) ret.value_ptr.* = CompSet.init(allocator);
            try ret.value_ptr.put(a, {});
        }
    }
    return pcs;
}

fn countParties(pcs: Computers) !usize {
    var ans: usize = 0;

    var visited = std.AutoHashMap([6]u8, void).init(allocator);
    defer visited.deinit();

    var party_it = pcs.iterator();
    while (party_it.next()) |el| {
        const a_id = el.key_ptr;
        const a_children = el.value_ptr;

        var a_it = a_children.keyIterator();
        while (a_it.next()) |b_id| {
            const b_children = pcs.get(b_id.*) orelse unreachable;

            var b_it = b_children.keyIterator();
            while (b_it.next()) |c_id| {
                const c_children = pcs.get(c_id.*) orelse unreachable;
                if (!c_children.contains(a_id.*)) continue;

                if (checkParty(&visited, a_id.*, b_id.*, c_id.*)) ans += 1;
            }
        }
    }

    return ans;
}

inline fn checkParty(visited: *std.AutoHashMap([6]u8, void), a_id: Id, b_id: Id, c_id: Id) bool {
    if (a_id[0] != 't' and b_id[0] != 't' and c_id[0] != 't') return false;
    const key = blk: {
        var key_array = [_]Id{ a_id, b_id, c_id };
        std.mem.sort(Id, &key_array, {}, lessThan);

        var key = [_]u8{0} ** 6;
        inline for (0..6) |i| key[i] = key_array[@divFloor(i, 2)][@rem(i, 2)];

        break :blk key;
    };
    if (visited.contains(key)) return false;
    visited.put(key, {}) catch unreachable;
    return true;
}

fn largestParty(pcs: Computers) ![]u8 {
    var party = LanParty{
        .pcs = pcs,
        .visited = CompSet.init(allocator),
        .largest_party = std.ArrayList(Id).init(allocator),
    };
    defer party.visited.deinit();
    defer party.largest_party.deinit();

    try party.findLargestParty();

    const largest = party.largest_party;
    std.mem.sort(Id, largest.items, {}, lessThan);

    const ret = try allocator.alloc(u8, largest.items.len * 3 - 1);
    for (largest.items, 0..) |id, i| {
        ret[i * 3] = id[0];
        ret[i * 3 + 1] = id[1];
        if (i != largest.items.len - 1) ret[i * 3 + 2] = ',';
    }
    return ret;
}

const LanParty = struct {
    pcs: Computers,
    visited: CompSet,
    largest_party: std.ArrayList(Id),

    fn findLargestParty(lp: *LanParty) !void {
        var p = std.ArrayList(Id).init(allocator);
        defer p.deinit();

        var it = lp.pcs.keyIterator();
        while (it.next()) |id| {
            lp.visited.clearRetainingCapacity();
            try lp.flpRec(&p, id.*);
        }
    }

    fn flpRec(lp: *LanParty, cur_party: *std.ArrayList(Id), new: Id) !void {
        if (lp.visited.contains(new)) return;
        try lp.visited.put(new, {});

        const children = lp.pcs.get(new) orelse unreachable;
        for (cur_party.items) |id| if (!children.contains(id)) return;

        try cur_party.append(new);
        defer _ = cur_party.pop();

        const cur_len = cur_party.items.len;
        if (lp.largest_party.items.len < cur_len) {
            try lp.largest_party.resize(cur_len);
            try lp.largest_party.replaceRange(0, cur_len, cur_party.items);
        }

        var it = children.keyIterator();
        while (it.next()) |child| try lp.flpRec(cur_party, child.*);
    }
};

fn lessThan(_: void, lid: Id, rid: Id) bool {
    return std.mem.lessThan(u8, &lid, &rid);
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
