const levenshtein = @import("levenshtein.zig");

pub usingnamespace levenshtein;

test "root: test all decls" {
    const std = @import("std");

    std.testing.refAllDecls(@This());
}
