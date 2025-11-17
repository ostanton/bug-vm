const std = @import("std");

pub const VirtualMachine = @import("VirtualMachine.zig");
pub const Assembler = @import("Assembler.zig");

/// Registers are 16-bit memory locations
pub const Register = enum(u3) {
    zero,
    r0,
    r1,
    r2,
    r3,
    r4,
    r5,
    r6,
};

/// Instructions are 16 bits long
/// Pseudo-instructions (like mov) translate into one or multiple normal instructions
/// For example:
/// mov r0 r1
/// translates into:
/// add r0 r1 zero
pub const Instruction = union(enum(u4)) {
    call: packed struct {
        opcode: u4 = @intFromEnum(Tag.call),
        /// The ID of the internal function to call
        fn_id: u12,
    },
    /// Adds two source registers into a destination register
    add: packed struct {
        opcode: u4 = @intFromEnum(Tag.add),
        dest: Register,
        src1: Register,
        src2: Register,
        /// Unused
        _1: u3 = 0,
    },
    /// Adds an immediate value with a source register into a destination register
    addi: packed struct {
        opcode: u4 = @intFromEnum(Tag.addi),
        dest: Register,
        src: Register,
        imm: u6,
    },
    /// Loads a value from memory into the target register
    load: packed struct {
        opcode: u4 = @intFromEnum(Tag.load),
        dest: Register,
        addr: u9,
    },
    /// Stores a value into memory from the source register
    store: packed struct {
        opcode: u4 = @intFromEnum(Tag.store),
        addr: u9,
        src: Register,
    },
    /// Compares the values of src1 and src2 registers and stores the result in the dest register
    cmp: packed struct {
        opcode: u4 = @intFromEnum(Tag.cmp),
        dest: Register,
        src1: Register,
        src2: Register,
        /// Unused
        _1: u3 = 0,
    },
    /// Absolute jump to an index in the program code if src1 register value == src2 register value
    jmp_eq: packed struct {
        opcode: u4 = @intFromEnum(Tag.jmp_eq),
        target: u9,
        src: Register,
    },
    /// Absolute jump to an index in the program code if src1 register value > src2 register value
    jmp_gt: packed struct {
        opcode: u4 = @intFromEnum(Tag.jmp_gt),
        target: u9,
        src: Register,
    },
    /// Absolute jump to an index in the program code if src1 register value >= src2 register value
    jmp_gte: packed struct {
        opcode: u4 = @intFromEnum(Tag.jmp_gte),
        target: u9,
        src: Register,
    },

    const Self = @This();

    pub const Tag = std.meta.Tag(Self);

    pub fn prettyPrint(self: Self) void {
        switch (self) {
            .call => |call| {
                std.debug.print(
                    \\Instruction: call
                    \\Function ID: {}
                , .{
                    call.fn_id,
                });
            },
            .add => |add| {
                std.debug.print(
                    \\Instruction: add
                    \\Destination: {}
                    \\Source 1   : {}
                    \\Source 2   : {}
                    \\
                , .{
                    add.dest,
                    add.src1,
                    add.src2,
                });
            },
            .addi => |addi| {
                std.debug.print(
                    \\Instruction: addi
                    \\Destination: {}
                    \\Source     : {}
                    \\Immediate  : {}
                    \\
                , .{
                    addi.dest,
                    addi.src,
                    addi.imm,
                });
            },
            .load => |load| {
                std.debug.print(
                    \\Instruction: load
                    \\Destination: {}
                    \\Address    : {}
                , .{
                    load.dest,
                    load.addr,
                });
            },
            .store => |store| {
                std.debug.print(
                    \\Instruction: store
                    \\Address    : {}
                    \\Source     : {}
                , .{
                    store.addr,
                    store.src,
                });
            },
            .cmp => |cmp| {
                std.debug.print(
                    \\Instruction: cmp
                    \\Destination: {}
                    \\Source 1   : {}
                    \\Source 2   : {}
                , .{
                    cmp.dest,
                    cmp.src1,
                    cmp.src2,
                });
            },
            .jmp_eq => |jmp| {
                std.debug.print(
                    \\Instruction: jmp_eq
                    \\Target     : {}
                    \\Source     : {}
                , .{
                    jmp.target,
                    jmp.src,
                });
            },
            .jmp_gt => |jmp| {
                std.debug.print(
                    \\Instruction: jmp_gt
                    \\Target     : {}
                    \\Source     : {}
                , .{
                    jmp.target,
                    jmp.src,
                });
            },
            .jmp_gte => |jmp| {
                std.debug.print(
                    \\Instruction: jmp_gte
                    \\Target     : {}
                    \\Source     : {}
                , .{
                    jmp.target,
                    jmp.src,
                });
            },
        }
    }

    pub fn inlinePrint(self: Self) void {
        switch (self) {
            .call => |call| std.debug.print("call {}\n", .{call.fn_id}),
            .add => |add| std.debug.print("add {} {} {}\n", .{ add.dest, add.src1, add.src2 }),
            .addi => |addi| std.debug.print("addi {} {} {}\n", .{ addi.dest, addi.src, addi.imm }),
            .load => |load| std.debug.print("load {} {}\n", .{ load.dest, load.addr }),
            .store => |store| std.debug.print("store {} {}\n", .{ store.addr, store.src }),
            .cmp => |cmp| std.debug.print("cmp {} {} {}\n", .{ cmp.dest, cmp.src1, cmp.src2 }),
            .jmp_eq => |jmp| std.debug.print("jmp_eq {} {}\n", .{ jmp.target, jmp.src }),
            .jmp_gt => |jmp| std.debug.print("jmp_gt {} {}\n", .{ jmp.target, jmp.src }),
            .jmp_gte => |jmp| std.debug.print("jmp_gte {} {}", .{ jmp.target, jmp.src }),
        }
    }

    pub fn decode(code: u16) Instruction {
        const opcode: Tag = @enumFromInt(@as(u4, @truncate(code & 0xF)));
        switch (opcode) {
            .call => return .{ .call = @bitCast(code) },
            .add => return .{ .add = @bitCast(code) },
            .addi => return .{ .addi = @bitCast(code) },
            .load => return .{ .load = @bitCast(code) },
            .store => return .{ .store = @bitCast(code) },
            .cmp => return .{ .cmp = @bitCast(code) },
            .jmp_eq => return .{ .jmp_eq = @bitCast(code) },
            .jmp_gt => return .{ .jmp_gt = @bitCast(code) },
            .jmp_gte => return .{ .jmp_gte = @bitCast(code) },
        }

        return .{
            .call = .{
                .fn_id = 0,
            },
        };
    }

    pub fn encode(self: Self) u16 {
        switch (self) {
            .call => |call| return @bitCast(call),
            .add => |add| return @bitCast(add),
            .addi => |addi| return @bitCast(addi),
            .load => |load| return @bitCast(load),
            .store => |store| return @bitCast(store),
            .cmp => |cmp| return @bitCast(cmp),
            .jmp_eq => |jmp| return @bitCast(jmp),
            .jmp_gt => |jmp| return @bitCast(jmp),
            .jmp_gte => |jmp| return @bitCast(jmp),
        }
        unreachable;
    }
};
