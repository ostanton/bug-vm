const std = @import("std");
const bug = @import("bug");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var assembler: bug.Assembler = .init;
    defer assembler.deinit(allocator);

    const file = try std.fs.cwd().openFile("test1.asm", .{});
    defer file.close();

    try assembler.assembleFromFile(allocator, file);

    var vm: bug.VirtualMachine = .init(assembler.bytecode.items);
    vm.execute();
}
