const std = @import("std");
const Ctx = @import("y.zig").Ctx;

pub fn main() void {
    var altStack: [4096]usize align(16) = undefined;
    var ctx: Ctx = undefined;
    ctx.start(
        @as([]usize, &altStack).ptr + altStack.len,
        @ptrCast(&iterFileChar),
        @intFromPtr(@as([*:0]const u8, "main.zig")),
    );
    while (ctx.next()) |v| std.debug.print("{c}", .{@as(u8, @intCast(v))});
    std.debug.print("\nGot {} chars\n", .{ctx.yieldValue});
}

fn iterFileChar(ctx: *Ctx, arg: [*:0]const u8) callconv(.C) usize {
    const file = std.fs.cwd().openFileZ(arg, .{}) catch return 0;
    defer file.close();
    var buffer: [256]u8 = undefined;
    var written: usize = 0;
    while (true) {
        const n = file.read(&buffer) catch break;
        if (n == 0) break;
        for (buffer[0..n]) |ch| {
            written += 1;
            ctx.yield(ch);
        }
    }
    return written;
}
