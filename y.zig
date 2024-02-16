comptime {
    asm (
        \\.global switchStack
        \\.type   switchStack, @function
        \\  switchStack:
        \\push %r15
        \\push %r14
        \\push %r13
        \\push %r12
        \\push %rbx
        \\push %rbp
        \\mov  %rsp, 0x00(%rdi)
        \\mov  0x00(%rsi), %rsp
        \\pop  %rbp
        \\pop  %rbx
        \\pop  %r12
        \\pop  %r13
        \\pop  %r14
        \\pop  %r15
        \\ret
        \\.global altInit
        \\.type   altInit, @function
        \\  altInit:
        \\pop %rdx
        \\pop %rsi
        \\pop %rdi
        \\ret
    );
}

extern fn switchStack(curr: *[*]usize, next: *[*]usize) callconv(.C) void;
extern fn altInit() callconv(.Naked) void; // never call this in zig

fn altStart(ctx: *Ctx, fun: *const fn (*Ctx, usize) callconv(.C) usize, arg: usize) callconv(.C) void {
    const ret = fun(ctx, arg);
    ctx.returned = true;
    while (true) ctx.yield(ret);
}

const SP = struct {
    ptr: [*]usize,
    pub fn push(self: *@This(), val: usize) void {
        self.ptr -= 1;
        self.ptr[0] = val;
    }
};

pub const Ctx = struct {
    const Self = @This();
    altSp: [*]usize,
    mainSp: [*]usize,
    yieldValue: usize,
    returned: bool,
    /// fun must be callconv(.C) with a *Ctx and a 64bit arg and returns 64bit or void
    pub fn start(self: *Self, sp: [*]usize, fun: *const fn (*Ctx, usize) callconv(.C) usize, arg: usize) void {
        var stk = SP{ .ptr = sp };
        stk.push(0);
        stk.push(@intFromPtr(&altStart));
        stk.push(@intFromPtr(self));
        stk.push(@intFromPtr(fun));
        stk.push(arg);
        stk.push(@intFromPtr(&altInit));
        stk.ptr -= 6;
        self.altSp = stk.ptr;
        self.returned = false;
        self.yieldValue = 0;
    }
    pub fn next(self: *Self) ?usize {
        switchStack(&self.mainSp, &self.altSp);
        if (self.returned) return null;
        return self.yieldValue;
    }
    pub fn yield(self: *Self, val: usize) void {
        self.yieldValue = val;
        switchStack(&self.altSp, &self.mainSp);
    }
};
