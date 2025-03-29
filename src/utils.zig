const std = @import("std");

fn min2(comptime t: type, a: t, b: t) t {
    if (a < b or a == b) return a;
    return b;
}

pub fn min3(comptime t: type, a: t, b: t, c: t) t {
    return min2(t, min2(t, a, b), c);
}

test "min3" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(1, min3(u8, 3, 1, 2));
    try expectEqual(1, min3(u8, 1, 3, 2));
    try expectEqual(1, min3(u8, 1, 2, 3));
    try expectEqual(1, min3(u8, 1, 1, 1));
}
