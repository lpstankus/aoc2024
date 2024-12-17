const std = @import("std");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub fn main() !void {
    defer _ = gpa.deinit();
    try solve("example");
    try solve("input");
}

fn solve(comptime name: []const u8) !void {
    var computer = try Computer.fromRaw(@embedFile(name));
    defer computer.deinit();

    println(">> {s}:", .{name});
    print("part 1: ", .{});
    computer.run();
    println("part 2: {}", .{computer.decorrupt()});
}

const Opcode = enum(u3) {
    adv = 0,
    bxl = 1,
    bst = 2,
    jnz = 3,
    bxc = 4,
    out = 5,
    bdv = 6,
    cdv = 7,
};

const Computer = struct {
    program: []Opcode,
    pc: usize = 0,
    A: u64,
    B: u64,
    C: u64,

    fn fromRaw(raw: []const u8) !Computer {
        var program = try std.ArrayList(Opcode).initCapacity(allocator, 100);
        defer program.deinit();

        var lines = std.mem.splitScalar(u8, raw, '\n');

        var regs = [_]u64{ 0, 0, 0 };
        inline for (&regs) |*reg| {
            var it = std.mem.splitAny(u8, lines.next() orelse unreachable, ": ");
            inline for (0..3) |_| _ = it.next();
            reg.* = try std.fmt.parseInt(u64, it.next() orelse unreachable, 10);
        }
        _ = lines.next();

        var it = std.mem.splitAny(u8, lines.next() orelse unreachable, " ,");
        _ = it.next();
        while (it.next()) |op| {
            const n = try std.fmt.parseInt(u3, op, 10);
            try program.append(@enumFromInt(n));
        }

        return .{
            .program = try allocator.dupe(Opcode, program.items),
            .A = regs[0],
            .B = regs[1],
            .C = regs[2],
        };
    }

    fn deinit(computer: *Computer) void {
        allocator.free(computer.program);
    }

    fn clone(computer: Computer) !Computer {
        return .{
            .program = try allocator.dupe(Opcode, computer.program),
            .A = computer.A,
            .B = computer.B,
            .C = computer.C,
        };
    }

    fn run(computer: *Computer) void {
        defer println("", .{});
        var ret = computer.step();
        while (ret != .halt) : (ret = computer.step()) {
            switch (ret) {
                .halt, .cont => continue,
                .output => |val| print("{},", .{val}),
            }
        }
    }

    fn decorrupt(computer: *Computer) u64 {
        return computer.decorruptRec(0, 1) catch unreachable;
    }

    fn decorruptRec(computer: *Computer, ans: u64, n: usize) !u64 {
        if (n > computer.program.len) return ans;
        const candidate = ans << 3;
        for (0..8) |i| {
            if (!computer.testOutput(candidate + i, n)) continue;
            return computer.decorruptRec(candidate | i, n + 1) catch continue;
        }
        return error.NotFound;
    }

    fn testOutput(computer: *Computer, A: u64, n: usize) bool {
        const cmp = computer.program[computer.program.len - n ..];
        var ptr: u64 = 0;

        computer.reset(A);
        var ret = computer.step();
        while (ret != .halt) : (ret = computer.step()) {
            switch (ret) {
                .halt, .cont => continue,
                .output => |val| {
                    if (ptr == cmp.len) return true;
                    if (val != @intFromEnum(cmp[@intCast(ptr)])) return false;
                    ptr += 1;
                },
            }
        }
        return ptr == cmp.len;
    }

    fn step(computer: *Computer) union(enum) { output: u64, cont: void, halt } {
        if (computer.pc + 1 >= computer.program.len) return .halt;
        switch (computer.program[computer.pc]) {
            .jnz => if (computer.A != 0) {
                computer.pc = computer.literal();
                return .cont;
            },
            .adv => computer.A = @divTrunc(computer.A, @as(u64, 1) << @intCast(computer.combo())),
            .bdv => computer.B = @divTrunc(computer.A, @as(u64, 1) << @intCast(computer.combo())),
            .cdv => computer.C = @divTrunc(computer.A, @as(u64, 1) << @intCast(computer.combo())),
            .bst => computer.B = computer.combo() & 0b0111,
            .bxl => computer.B = computer.B ^ computer.literal(),
            .bxc => computer.B = computer.B ^ computer.C,
            .out => {
                defer computer.pc += 2;
                return .{ .output = computer.combo() & 0b0111 };
            },
        }
        computer.pc += 2;
        return .cont;
    }

    inline fn combo(computer: Computer) u64 {
        const lit: u64 = computer.literal();
        return switch (lit) {
            0...3 => lit,
            4 => computer.A,
            5 => computer.B,
            6 => computer.C,
            else => unreachable,
        };
    }

    inline fn literal(computer: Computer) u64 {
        return @intFromEnum(computer.program[computer.pc + 1]);
    }

    fn reset(computer: *Computer, A: u64) void {
        computer.A = A;
        computer.B = 0;
        computer.C = 0;
        computer.pc = 0;
    }
};

const print = std.debug.print;
fn println(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}
