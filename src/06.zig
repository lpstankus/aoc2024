const std = @import("std");

const verbose = false;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Dir = enum(u8) { Up, Right, Down, Left, Mult };
const Guard = struct { x: i32, y: i32, dir: Dir };

const Pos = union(enum) { Block: ?Dir, Free: ?Dir };
const Row = std.ArrayList(Pos);
const Map = std.ArrayList(Row);

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    const data = try parseInput(@embedFile(name));
    defer {
        var map = data.map;
        defer map.deinit();
        for (map.items) |row| row.deinit();
    }

    const ans1 = part1(data.map, data.guard);
    const ans2 = part2(data.map, data.guard);

    println(">> {s}:", .{name});
    println("part 1: {}", .{ans1});
    println("part 2: {}", .{ans2});
}

fn parseInput(data: []const u8) !struct { map: Map, guard: Guard } {
    var guard: Guard = undefined;
    var map = Map.init(allocator);

    var i: usize = 0;
    var lines = std.mem.split(u8, data, "\n");
    while (lines.next()) |line| : (i += 1) {
        var row = Row.init(allocator);
        for (line, 0..) |c, j| {
            switch (c) {
                '#' => try row.append(.{ .Block = null }),
                '.' => try row.append(.{ .Free = null }),
                '<' => {
                    try row.append(.{ .Free = null });
                    guard = .{ .y = @intCast(i), .x = @intCast(j), .dir = .Left };
                },
                '^' => {
                    try row.append(.{ .Free = null });
                    guard = .{ .y = @intCast(i), .x = @intCast(j), .dir = .Up };
                },
                '>' => {
                    try row.append(.{ .Free = null });
                    guard = .{ .y = @intCast(i), .x = @intCast(j), .dir = .Right };
                },
                'v' => {
                    try row.append(.{ .Free = null });
                    guard = .{ .y = @intCast(i), .x = @intCast(j), .dir = .Down };
                },
                else => unreachable,
            }
        }
        try map.append(row);
    }
    return .{ .map = map, .guard = guard };
}

fn part1(map: Map, guard: Guard) u32 {
    var g = guard;
    var sum: u32 = 1;
    while (true) {
        const ng = moveGuard(map, g) orelse break;
        g = switch (getPos(map, ng.x, ng.y).*) {
            .Block => rotateGuard(g),
            .Free => |*val| blk: {
                if (val.* == null) {
                    val.* = ng.dir;
                    sum += 1;
                }
                break :blk ng;
            },
        };
        if (comptime verbose) {
            visit(map, g);
            printMap(map, g);
        }
    }
    return sum;
}

fn part2(map: Map, guard: Guard) u32 {
    // clear map
    for (map.items) |row| {
        for (row.items) |*pos| {
            pos.* = switch (pos.*) {
                .Block => .{ .Block = null },
                .Free => .{ .Free = null },
            };
        }
    }

    var g = guard;
    var sum: u32 = 0;
    while (true) {
        const ng = moveGuard(map, g) orelse break;
        const pos = getPos(map, ng.x, ng.y);
        g = switch (pos.*) {
            .Block => rotateGuard(g),
            .Free => |*val| blk: {
                if (val.* == null) {
                    pos.* = .{ .Block = null };
                    if (hasLoop(map, g)) sum += 1;
                    pos.* = .{ .Free = ng.dir };
                }
                break :blk ng;
            },
        };
    }

    return sum;
}

fn hasLoop(map: Map, guard: Guard) bool {
    var slow = guard;
    var fast = blk: {
        const ns = moveGuard(map, guard) orelse return false;
        break :blk switch (getPos(map, ns.x, ns.y).*) {
            .Block => rotateGuard(guard),
            .Free => ns,
        };
    };

    while (true) {
        if (slow.x == fast.x and slow.y == fast.y and slow.dir == fast.dir) return true;

        const ns = moveGuard(map, slow) orelse return false;
        switch (getPos(map, ns.x, ns.y).*) {
            .Block => slow = rotateGuard(slow),
            .Free => slow = ns,
        }
        for (0..2) |_| {
            const nf = moveGuard(map, fast) orelse return false;
            switch (getPos(map, nf.x, nf.y).*) {
                .Block => fast = rotateGuard(fast),
                .Free => fast = nf,
            }
        }
    }

    return false;
}

fn getPos(map: Map, x: i32, y: i32) *Pos {
    return &map.items[@intCast(y)].items[@intCast(x)];
}

fn visit(map: Map, guard: Guard) void {
    const pos = getPos(map, guard.x, guard.y);
    switch (pos.*) {
        .Block => return,
        .Free => |maybe| if (maybe == null) return,
    }

    const dir = pos.Free.?;
    const ndir = switch (dir) {
        .Right, .Left => ndir: {
            break :ndir switch (guard.dir) {
                .Up, .Down => .Mult,
                .Right, .Left => dir,
                .Mult => unreachable,
            };
        },
        .Up, .Down => ndir: {
            break :ndir switch (guard.dir) {
                .Up, .Down => dir,
                .Right, .Left => .Mult,
                .Mult => unreachable,
            };
        },
        .Mult => .Mult,
    };
    pos.* = .{ .Free = ndir };
}

fn moveGuard(map: Map, guard: Guard) ?Guard {
    const ng = switch (guard.dir) {
        .Up => .{ .x = guard.x, .y = guard.y - 1, .dir = guard.dir },
        .Right => .{ .x = guard.x + 1, .y = guard.y, .dir = guard.dir },
        .Down => .{ .x = guard.x, .y = guard.y + 1, .dir = guard.dir },
        .Left => .{ .x = guard.x - 1, .y = guard.y, .dir = guard.dir },
        .Mult => unreachable,
    };
    const in_bounds =
        (0 <= ng.y and ng.y < map.items.len) and
        (0 <= ng.x and ng.x < map.items[@intCast(ng.y)].items.len);
    if (!in_bounds) return null;
    return ng;
}

fn rotateGuard(guard: Guard) Guard {
    const dir: Dir = switch (guard.dir) {
        .Up => .Right,
        .Right => .Down,
        .Down => .Left,
        .Left => .Up,
        .Mult => unreachable,
    };
    return .{ .x = guard.x, .y = guard.y, .dir = dir };
}

fn printMap(map: Map, guard: Guard) void {
    for (map.items, 0..) |row, i| {
        for (row.items, 0..) |pos, j| {
            if (guard.x == j and guard.y == i) {
                const char: u8 = switch (guard.dir) {
                    .Up => '^',
                    .Right => '>',
                    .Down => 'v',
                    .Left => '<',
                    .Mult => unreachable,
                };
                print("{c}", .{char});
                continue;
            }
            switch (pos) {
                .Block => print("#", .{}),
                .Free => |maybe| {
                    const char: u8 = if (maybe) |val| blk: {
                        break :blk switch (val) {
                            .Up, .Down => '|',
                            .Right, .Left => '-',
                            .Mult => '+',
                        };
                    } else '.';
                    print("{c}", .{char});
                },
            }
        }
        println("", .{});
    }
}

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
