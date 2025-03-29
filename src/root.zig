pub const levenshtein = @import("levenshtein.zig");

test "root: test all decls" {
    const std = @import("std");

    std.testing.refAllDecls(@This());
}
