const std = @import("std");
const VirtualMachine = @import("VirtualMachine.zig");

pub fn execute(vm: *VirtualMachine, id: u12) void {
    switch (id) {
        0 => exit(vm, vm.getRegister(.r0)),
        1 => print(vm.getRegister(.r0)),
        else => std.debug.print("Calling an unsupported ID {}\n", .{id}),
    }
}

/// Exits the program with the error code
/// # Parameters
/// - r0: Error code
fn exit(vm: *VirtualMachine, code: u16) void {
    vm.exit_status = code;
    vm.pc = vm.program.len;
}

/// Prints the integer value
/// # Parameters
/// - r0: Value to print
fn print(value: u16) void {
    std.debug.print("{}\n", .{value});
}
