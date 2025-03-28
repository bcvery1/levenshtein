const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn distance(comptime t: type, allocator: Allocator, a: []const t, b: []const t) Allocator.Error!usize {
    const rows = a.len + 1;
    const cols = b.len + 1;

    var dp = try create_matrix(usize, allocator, rows, cols);
    defer deinit_matrix(usize, allocator, dp);

    // Initialise matrix values
    for (0..rows) |i| {
        dp[i][0] = i;
    }
    for (0..cols) |i| {
        dp[0][i] = i;
    }

    // Calculate distance
    for (1..rows) |i| {
        for (1..cols) |j| {
            dp[i][j] = blk: {
                if (a[i - 1] == b[j - 1]) {
                    break :blk dp[i - 1][j - 1];
                }

                break :blk min3(
                    usize,
                    dp[i - 1][j - 1] + 1, // Substitution
                    dp[i][j - 1] + 1, // Insertion
                    dp[i - 1][j] + 1, // Deletion
                );
            };
        }
    }

    return dp[rows - 1][cols - 1];
}

test "distance" {
    const alloc = std.testing.allocator;
    try std.testing.expectEqual(3, try distance(u8, alloc, "kitten", "sitting"));
}

fn create_matrix(comptime t: type, allocator: Allocator, rows: usize, cols: usize) Allocator.Error![][]t {
    var matrix: [][]t = try allocator.alloc([]t, rows);
    for (0..rows) |row| {
        matrix[row] = try allocator.alloc(t, cols);
    }
    return matrix;
}

fn deinit_matrix(comptime t: type, allocator: Allocator, matrix: [][]t) void {
    for (0..matrix.len) |i| {
        allocator.free(matrix[i]);
    }
    allocator.free(matrix);
}

fn min2(comptime t: type, a: t, b: t) t {
    if (a < b or a == b) return a;
    return b;
}

fn min3(comptime t: type, a: t, b: t, c: t) t {
    return min2(t, min2(t, a, b), c);
}

test "min3" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(1, min3(u8, 3, 1, 2));
    try expectEqual(1, min3(u8, 1, 3, 2));
    try expectEqual(1, min3(u8, 1, 2, 3));
    try expectEqual(1, min3(u8, 1, 1, 1));
}
