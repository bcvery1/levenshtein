const std = @import("std");

const matrix = @import("matrix.zig");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub const Error = matrix.Error || Allocator.Error;

pub fn distance(comptime t: type, allocator: Allocator, a: []const t, b: []const t) Error!usize {
    const rows = a.len + 1;
    const cols = b.len + 1;

    var dp = try matrix.Matrix(usize).init(allocator, rows, cols);
    defer dp.deinit();

    // Set the first row and first column to be equal to their indexes (column for row, and row for column).
    dp.run_row_col(set_to_index);

    // Calculate distance
    for (1..rows) |row| {
        for (1..cols) |col| {
            const prev_row = row - 1;
            const prev_col = col - 1;

            const new_value = blk: {
                if (a[prev_row] == b[prev_col]) {
                    break :blk try dp.get(prev_row, prev_col);
                }

                break :blk utils.min3(
                    usize,
                    try dp.get(prev_row, prev_col) + 1, // Substitution
                    try dp.get(row, prev_col) + 1, // Insertion
                    try dp.get(prev_row, col) + 1, // Deletion
                );
            };
            try dp.set(row, col, new_value);
        }
    }

    return dp.get_last();
}

fn set_to_index(mat: *matrix.Matrix(usize), row: usize, col: usize, _: usize) void {
    if (row == 0) mat.set(row, col, col) catch unreachable;
    if (col == 0) mat.set(row, col, row) catch unreachable;
}

test "distance" {
    const alloc = std.testing.allocator;
    const expectEqual = std.testing.expectEqual;

    try expectEqual(3, try distance(u8, alloc, "kitten", "sitting"));
    try expectEqual(0, try distance(u8, alloc, "kitten", "kitten"));
    try expectEqual(6, try distance(u8, alloc, "kitten", "food"));
    try expectEqual(1, try distance(u8, alloc, "foo", "food"));
}
