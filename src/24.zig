const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

const Reg = [3]u8;
const OpType = enum { AND, OR, XOR };
const Op = struct { tp: OpType, reg0: Reg, reg1: Reg };

const OpMap = std.AutoHashMap(Reg, Op);
const RevOpMap = std.AutoHashMap(Op, Reg);
const RegMap = std.AutoHashMap(Reg, bool);

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var data = try parseInput(@embedFile(name));
    defer data.regs.deinit();
    defer data.ops.deinit();
    defer data.rev.deinit();

    println(">> {s}:", .{name});
    println("part 1: {}", .{try part1(data.ops, data.regs)});

    if (std.mem.eql(u8, name, "input")) {
        print("part 2: ", .{});
        try part2(data.ops, data.rev, data.nbits);
    }
}

fn parseInput(raw: []const u8) !struct { ops: OpMap, rev: RevOpMap, regs: RegMap, nbits: usize } {
    var ops = OpMap.init(allocator);
    var rev = RevOpMap.init(allocator);
    var regs = RegMap.init(allocator);

    var nbits: usize = 0;
    var lines = std.mem.splitScalar(u8, raw, '\n');
    while (lines.next()) |line| : (nbits += 1) {
        if (line.len == 0) break;
        std.debug.assert(line[5] == '1' or line[5] == '0');

        const reg: Reg = line[0..3].*;
        try regs.put(reg, line[5] == '1');
    }

    while (lines.next()) |line| {
        if (line.len == 0) break;
        switch (line[4]) {
            'X', 'A' => |char| {
                const reg0 = line[0..3].*;
                const reg1 = line[8..11].*;
                const reg_out = line[15..18].*;
                const optype: OpType = if (char == 'X') .XOR else .AND;
                try ops.put(reg_out, .{ .tp = optype, .reg0 = reg0, .reg1 = reg1 });
                try rev.put(.{ .tp = optype, .reg0 = reg0, .reg1 = reg1 }, reg_out);
            },
            'O' => {
                const reg0 = line[0..3].*;
                const reg1 = line[7..10].*;
                const reg_out = line[14..17].*;
                try ops.put(reg_out, .{ .tp = .OR, .reg0 = reg0, .reg1 = reg1 });
                try rev.put(.{ .tp = .OR, .reg0 = reg0, .reg1 = reg1 }, reg_out);
            },
            else => unreachable,
        }
    }

    return .{ .ops = ops, .rev = rev, .regs = regs, .nbits = @divFloor(nbits, 2) };
}

fn part1(ops: OpMap, regs: RegMap) !usize {
    var copy_unso = try ops.clone();
    defer copy_unso.deinit();

    var copy_regs = try regs.clone();
    defer copy_regs.deinit();

    try resolve(&copy_unso, &copy_regs);
    return try buildNumber(copy_regs, 'z');
}

fn part2(input_ops: OpMap, input_rev: RevOpMap, nbits: usize) !void {
    var errors = std.ArrayList(Reg).init(allocator);
    defer errors.deinit();

    var ops = try input_ops.clone();
    defer ops.deinit();

    var rev = try input_rev.clone();
    defer rev.deinit();

    var swapRegs = [_]Reg{
        regFromStr("fkb"),
        regFromStr("z16"),
        regFromStr("nnr"),
        regFromStr("rqf"),
        regFromStr("rdn"),
        regFromStr("z31"),
        regFromStr("rrn"),
        regFromStr("z37"),
    };

    var it = std.mem.window(Reg, &swapRegs, 2, 2);
    while (it.next()) |win| swapOps(&ops, &rev, win[0], win[1]);

    var carry_out = blk: {
        const reg_x = regid('x', 0);
        const reg_y = regid('y', 0);
        const xor_out = try findReg(rev, .{ .tp = .XOR, .reg0 = reg_x, .reg1 = reg_y });
        if (!regEql(xor_out, regid('z', 0))) {
            println("failing at zero...", .{});
            unreachable;
        }

        break :blk try findReg(rev, .{ .tp = .AND, .reg0 = reg_x, .reg1 = reg_y });
    };

    for (1..nbits) |bit| {
        const reg_x = regid('x', bit);
        const reg_y = regid('y', bit);
        const reg_z = regid('z', bit);

        const xor0_out = findReg(rev, .{ .tp = .XOR, .reg0 = reg_x, .reg1 = reg_y }) catch {
            println("bit {:0>2}: WTF", .{bit});
            unreachable;
        };

        const xor1_out = findReg(rev, .{ .tp = .XOR, .reg0 = xor0_out, .reg1 = carry_out }) catch {
            const exp_op = ops.get(reg_z) orelse unreachable;
            const exp_out = if (regEql(exp_op.reg0, carry_out)) exp_op.reg1 else exp_op.reg0;
            println("bit {:0>2}: xor 0 with swapped ({s} <-> {s})", .{ bit, xor0_out, exp_out });
            unreachable;
        };

        if (!regEql(reg_z, xor1_out)) {
            println("bit {:0>2}: xor 1 with swapped ({s} <-> {s})", .{ bit, xor1_out, reg_z });
            unreachable;
        }

        const ab_carry_out = findReg(rev, .{ .tp = .AND, .reg0 = reg_x, .reg1 = reg_y }) catch {
            println("bit {:0>2}: WTF", .{bit});
            unreachable;
        };

        const xc_carry_out = findReg(rev, .{ .tp = .AND, .reg0 = xor0_out, .reg1 = carry_out }) catch {
            println("bit {:0>2}: WTF", .{bit});
            unreachable;
        };

        carry_out = findReg(rev, .{ .tp = .OR, .reg0 = ab_carry_out, .reg1 = xc_carry_out }) catch {
            println("bit {:0>2}: some type of carry fail", .{bit});
            unreachable;
        };
    }

    std.mem.sort(Reg, &swapRegs, {}, asc);

    print("{s}", .{swapRegs[0]});
    for (swapRegs[1..]) |reg| print(",{s}", .{reg});
    println("", .{});
}

fn resolve(ops: *OpMap, regs: *RegMap) !void {
    while (ops.count() > 0) {
        var it = ops.keyIterator();
        const key = it.next().?;
        _ = try resolveRec(ops, regs, key.*);
    }
}

fn resolveRec(ops: *OpMap, regs: *RegMap, reg: Reg) !bool {
    const op = ops.get(reg).?;
    defer _ = ops.remove(reg);

    const l = regs.get(op.reg0) orelse try resolveRec(ops, regs, op.reg0);
    const r = regs.get(op.reg1) orelse try resolveRec(ops, regs, op.reg1);

    const val = execOp(op.tp, l, r);
    try regs.put(reg, val);
    return val;
}

inline fn buildNumber(regs: RegMap, prefix: u8) !usize {
    var rs = std.ArrayList([3]u8).init(allocator);
    defer rs.deinit();

    var it = regs.keyIterator();
    while (it.next()) |key| if (key[0] == prefix) try rs.append(key.*);

    std.mem.sort(Reg, rs.items, {}, desc);

    var ans: usize = 0;
    for (rs.items) |reg| ans = if (regs.get(reg).?) (ans << 1) | 1 else ans << 1;
    return ans;
}

inline fn execOp(op: OpType, l: bool, r: bool) bool {
    return switch (op) {
        .AND => l and r,
        .OR => l or r,
        .XOR => !(l and r) and (l or r),
    };
}

inline fn findReg(rev: RevOpMap, op: Op) !Reg {
    if (rev.get(op)) |reg| return reg;
    const swapped = Op{ .tp = op.tp, .reg0 = op.reg1, .reg1 = op.reg0 };
    if (rev.get(swapped)) |reg| return reg;
    return error.OpNotFound;
}

inline fn swapOps(ops: *OpMap, rev: *RevOpMap, a: Reg, b: Reg) void {
    const a_op = ops.get(a) orelse unreachable;
    const b_op = ops.get(b) orelse unreachable;

    ops.putAssumeCapacity(a, b_op);
    rev.putAssumeCapacity(a_op, b);

    ops.putAssumeCapacity(b, a_op);
    rev.putAssumeCapacity(b_op, a);
}

inline fn isOpInput(op: Op, reg: Reg) bool {
    if (regEql(op.reg0, reg)) return true;
    if (regEql(op.reg1, reg)) return true;
    return false;
}

inline fn regFromStr(comptime str: []const u8) Reg {
    std.debug.assert(str.len == 3);
    return .{ str[0], str[1], str[2] };
}

inline fn regid(reg: u8, val: usize) Reg {
    return .{ reg, @intCast('0' + @divFloor(val, 10)), @intCast('0' + @mod(val, 10)) };
}

inline fn regEql(l: Reg, r: Reg) bool {
    inline for (0..3) |i| if (l[i] != r[i]) return false;
    return true;
}

fn asc(_: void, l: Reg, r: Reg) bool {
    for (0..3) |i| {
        if (l[i] == r[i]) continue;
        return l[i] < r[i];
    }
    return false;
}

fn desc(_: void, l: Reg, r: Reg) bool {
    for (0..3) |i| {
        if (l[i] == r[i]) continue;
        return l[i] > r[i];
    }
    return false;
}

const print = std.debug.print;
inline fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
