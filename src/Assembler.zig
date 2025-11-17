const std = @import("std");
const root = @import("root.zig");
const Instruction = root.Instruction;
const Register = root.Register;

labels: std.StringHashMapUnmanaged(u16),
bytecode: std.ArrayList(u16),

const AssemblerError = error{
    OutOfMemory,
    InvalidParse,
    Overflow,
    Unknown,
};

const Self = @This();

pub const init: Self = .{
    .labels = .empty,
    .bytecode = .empty,
};

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.labels.deinit(allocator);
    self.bytecode.deinit(allocator);
}

pub fn assembleFromSource(self: *Self, allocator: std.mem.Allocator, source: []const u8) AssemblerError!void {
    std.debug.print("Assembling source code:\n{s}\n", .{source});
    try self.labelPass(allocator, source);
    try self.assemblePass(allocator, source);
    std.debug.print("Finished assembling bytecode:\n{any}\n", .{self.bytecode.items});
}

pub fn assembleFromFile(self: *Self, allocator: std.mem.Allocator, file: std.fs.File) AssemblerError!void {
    const source = file.readToEndAlloc(allocator, 2048) catch return AssemblerError.Unknown;
    defer allocator.free(source);
    try self.assembleFromSource(allocator, source);
}

fn labelPass(
    self: *Self,
    allocator: std.mem.Allocator,
    source: []const u8,
) AssemblerError!void {
    std.debug.print("Starting label pass\n", .{});
    var lines = std.mem.splitScalar(u8, source, '\n');
    var addr: u16 = 0;
    while (lines.next()) |line| {
        const trimmed: []const u8 = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) {
            continue;
        }

        const code = if (std.mem.indexOf(u8, trimmed, ";")) |index|
            std.mem.trim(u8, trimmed[0..index], " \t")
        else
            trimmed;

        if (code.len == 0) {
            continue;
        }

        if (std.mem.endsWith(u8, code, ":")) {
            const label = code[0 .. code.len - 1];
            self.labels.put(allocator, label, addr) catch return AssemblerError.OutOfMemory;
            std.debug.print("Found label '{s}' at address {}\n", .{ label, addr });
        } else {
            addr += 1;
        }
    }
}

fn assemblePass(
    self: *Self,
    allocator: std.mem.Allocator,
    source: []const u8,
) AssemblerError!void {
    std.debug.print("\nStarting assemble pass\n", .{});
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        const trimmed: []const u8 = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) {
            continue;
        }

        const code = if (std.mem.indexOf(u8, trimmed, ";")) |index|
            std.mem.trim(u8, trimmed[0..index], " \t")
        else
            trimmed;

        if (code.len == 0) {
            continue;
        }

        if (std.mem.endsWith(u8, code, ":")) {
            continue;
        }

        try self.parseInstruction(allocator, code);
    }
}

fn parseInstruction(self: *Self, allocator: std.mem.Allocator, line: []const u8) AssemblerError!void {
    std.debug.print("Parsing instruction: {s}\n", .{line});

    var parts = std.mem.tokenizeAny(u8, line, " \t");
    const nextPart = struct {
        pub fn nextPart(parts2: *std.mem.TokenIterator(u8, .any)) AssemblerError![]const u8 {
            return parts2.next() orelse return AssemblerError.InvalidParse;
        }
    }.nextPart;
    const mnemonic = parts.next() orelse return AssemblerError.InvalidParse;

    const tag = std.meta.stringToEnum(Instruction.Tag, mnemonic) orelse return AssemblerError.InvalidParse;

    const instruction: Instruction = switch (tag) {
        .call => blk: {
            const fn_id = try parseImmediate(u12, try nextPart(&parts));
            break :blk .{ .call = .{ .fn_id = fn_id } };
        },
        .add => blk: {
            const dest: Register = try parseRegister(try nextPart(&parts));
            const src1: Register = try parseRegister(try nextPart(&parts));
            const src2: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .add = .{
                .dest = dest,
                .src1 = src1,
                .src2 = src2,
            } };
        },
        .addi => blk: {
            const dest: Register = try parseRegister(try nextPart(&parts));
            const src: Register = try parseRegister(try nextPart(&parts));
            const imm = try parseImmediate(u6, try nextPart(&parts));
            break :blk .{ .addi = .{
                .dest = dest,
                .src = src,
                .imm = imm,
            } };
        },
        .load => blk: {
            const dest: Register = try parseRegister(try nextPart(&parts));
            const addr = try parseImmediate(u9, try nextPart(&parts));
            break :blk .{ .load = .{
                .dest = dest,
                .addr = addr,
            } };
        },
        .store => blk: {
            const addr = try parseImmediate(u9, try nextPart(&parts));
            const src: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .store = .{
                .addr = addr,
                .src = src,
            } };
        },
        .cmp => blk: {
            const dest: Register = try parseRegister(try nextPart(&parts));
            const src1: Register = try parseRegister(try nextPart(&parts));
            const src2: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .cmp = .{
                .dest = dest,
                .src1 = src1,
                .src2 = src2,
            } };
        },
        .jmp_eq => blk: {
            const target = try self.parseAddress(try nextPart(&parts));
            const src: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .jmp_eq = .{
                .target = target,
                .src = src,
            } };
        },
        .jmp_gt => blk: {
            const target = try self.parseAddress(try nextPart(&parts));
            const src: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .jmp_gt = .{
                .target = target,
                .src = src,
            } };
        },
        .jmp_gte => blk: {
            const target = try self.parseAddress(try nextPart(&parts));
            const src: Register = try parseRegister(try nextPart(&parts));
            break :blk .{ .jmp_gte = .{
                .target = target,
                .src = src,
            } };
        },
    };

    self.bytecode.append(allocator, instruction.encode()) catch return AssemblerError.OutOfMemory;
}

fn parseRegister(operand: []const u8) AssemblerError!Register {
    return std.meta.stringToEnum(Register, operand) orelse return AssemblerError.InvalidParse;
}

fn parseImmediate(comptime T: type, operand: []const u8) AssemblerError!T {
    return std.fmt.parseInt(T, operand, 0) catch |err| switch (err) {
        error.Overflow => AssemblerError.Overflow,
        error.InvalidCharacter => AssemblerError.InvalidParse,
    };
}

fn parseAddress(self: Self, operand: []const u8) AssemblerError!u9 {
    if (self.labels.get(operand)) |addr| {
        return @truncate(addr);
    }

    return std.fmt.parseInt(u9, operand, 0) catch return AssemblerError.InvalidParse;
}
