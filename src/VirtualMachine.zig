const std = @import("std");
const root = @import("root.zig");
const call_fns = @import("call_fns.zig");
const Instruction = root.Instruction;
const Register = root.Register;

const memory_size = 65_536;

const ComparisonResult = enum(u2) {
    equal,
    greater_than,
    greater_equal,
};

memory: [memory_size]u16 = @splat(0),
/// 8 registers in total, max number of a u3
registers: [8]u16 = @splat(0),
pc: usize = 0,
program: []const u16,
jumped: bool = false,
exit_status: u16 = 0,

const Self = @This();

pub fn init(program: []const u16) Self {
    return .{
        .program = program,
    };
}

pub fn getRegister(self: Self, register: Register) u16 {
    return self.registers[@intFromEnum(register)];
}

pub fn getRegisterPtr(self: *Self, register: Register) ?*u16 {
    if (register == .zero) {
        return null;
    }

    return &self.registers[@intFromEnum(register)];
}

pub fn setRegister(self: *Self, dest: Register, value: u16) void {
    if (dest == .zero) {
        std.debug.print("Zero register cannot be changed!\n", .{});
        return;
    }

    self.registers[@intFromEnum(dest)] = value;
}

pub fn setMemory(self: *Self, addr: usize, value: u16) void {
    if (addr == 0) {
        std.debug.print("Zero memory address cannot be changed!\n", .{});
        return;
    }

    self.memory[addr] = value;
}

pub fn execute(self: *Self) void {
    std.debug.print("\nVirtual machine executing bytecode:\n{any}\n", .{self.program});
    const start_time = std.time.milliTimestamp();
    while (self.pc < self.program.len) : ({
        if (!self.jumped) {
            self.pc += 1;
        } else {
            self.jumped = false;
        }
    }) {
        self.executeInstruction(.decode(self.program[self.pc]));
    }
    const end_time = std.time.milliTimestamp();
    std.debug.print("Exited with status: {}\n", .{self.exit_status});
    std.debug.print("Execution took {} ms\n", .{end_time - start_time});
}

pub fn executeInstruction(self: *Self, instruction: Instruction) void {
    std.debug.print("=> ", .{});
    instruction.inlinePrint();
    switch (instruction) {
        .call => |call| call_fns.execute(self, call.fn_id),
        .add => |add| {
            const src1 = self.getRegister(add.src1);
            const src2 = self.getRegister(add.src2);
            self.setRegister(add.dest, src1 +% src2);
        },
        .addi => |addi| {
            const src = self.getRegister(addi.src);
            self.setRegister(addi.dest, src +% addi.imm);
        },
        .load => |load| {
            self.setRegister(load.dest, self.memory[load.addr]);
        },
        .store => |store| {
            self.setMemory(store.addr, self.getRegister(store.src));
        },
        .cmp => |cmp| {
            const src1 = self.getRegister(cmp.src1);
            const src2 = self.getRegister(cmp.src2);
            const dest = self.getRegisterPtr(cmp.dest);
            if (dest) |d| {
                if (src1 > src2) {
                    d.* = @intFromEnum(ComparisonResult.greater_than);
                } else if (src1 == src2) {
                    d.* = @intFromEnum(ComparisonResult.equal);
                } else if (src1 >= src2) {
                    d.* = @intFromEnum(ComparisonResult.greater_equal);
                }
            }
        },
        .jmp_eq => |jmp| {
            const src: ComparisonResult = @enumFromInt(self.getRegister(jmp.src));

            if (src == .equal) {
                self.jumpTo(jmp.target);
            }
        },
        .jmp_gt => |jmp| {
            const src: ComparisonResult = @enumFromInt(self.getRegister(jmp.src));

            if (src == .greater_than) {
                self.jumpTo(jmp.target);
            }
        },
        .jmp_gte => |jmp| {
            const src: ComparisonResult = @enumFromInt(self.getRegister(jmp.src));

            if (src == .greater_equal) {
                self.jumpTo(jmp.target);
            }
        },
    }
}

fn jumpTo(self: *Self, target: usize) void {
    if (target >= self.program.len) {
        return;
    }

    self.pc = target;
    self.jumped = true;
}
