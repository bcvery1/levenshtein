const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    /// Coordinates provided are outside the Matrix.
    OutOfRange,
};

/// A 2 dimensional array with a fixed size.
/// This struct internally stores a 'std.mem.Allocator'.
pub fn Matrix(comptime t: type) type {
    return struct {
        const Self = @This();

        /// Contents of the Matrix.
        mat: [][]t = undefined,
        allocator: Allocator = undefined,
        /// Count of rows in the Matrix.
        rows: usize = 0,
        /// Count of columns in the Matrix.
        cols: usize = 0,

        /// Initialise the Matrix with set values.
        /// Caller must call 'deinit' to free memory.
        pub fn init(allocator: Allocator, rows: usize, cols: usize) Allocator.Error!Self {
            var m = Self{
                .mat = try allocator.alloc([]t, rows),
                .allocator = allocator,
                .rows = rows,
                .cols = cols,
            };
            for (0..rows) |row| {
                m.mat[row] = try allocator.alloc(t, cols);
            }
            return m;
        }

        /// Free all resources allocated by the struct.
        pub fn deinit(self: Self) void {
            for (0..self.rows) |row| {
                self.allocator.free(self.mat[row]);
            }
            self.allocator.free(self.mat);
        }

        /// Flush the Matrix with a single value. If this is not called, there is no guarantee the
        /// contents of any given cell is valid unless the caller has set it.
        pub fn flush(self: *Self, value: t) void {
            for (0..self.rows) |row| {
                for (0..self.cols) |col| {
                    self.mat[row][col] = value;
                }
            }
        }

        /// Flush one row of the Matrix with a single value.
        pub fn flush_row(self: *Self, row: usize, value: t) Error!void {
            if (self.invalid_coord(row, 0)) return Error.OutOfRange;
            for (0..self.cols) |col| {
                self.mat[row][col] = value;
            }
        }

        /// Flush one column of the Matrix with a single value.
        pub fn flush_col(self: *Self, col: usize, value: t) Error!void {
            if (self.invalid_coord(0, col)) return Error.OutOfRange;
            for (0..self.rows) |row| {
                self.mat[row][col] = value;
            }
        }

        /// Set a specific cell with a value.
        pub fn set(self: *Self, row: usize, col: usize, value: t) Error!void {
            if (self.invalid_coord(row, col)) return Error.OutOfRange;
            self.mat[row][col] = value;
        }

        /// Retrieve a specific cell's value.
        pub fn get(self: Self, row: usize, col: usize) Error!t {
            if (self.invalid_coord(row, col)) return Error.OutOfRange;
            return self.mat[row][col];
        }

        /// Retrieve the value of the cell in the last row, last column.
        pub fn get_last(self: Self) t {
            return self.get(self.rows - 1, self.cols - 1) catch unreachable;
        }

        pub fn run_row_col(self: *Self, comptime f: fn (mat: *Self, row: usize, col: usize, value: t) void) void {
            for (0..self.rows) |row| {
                for (0..self.cols) |col| {
                    const value = self.get(row, col) catch unreachable;
                    f(self, row, col, value);
                }
            }
        }

        pub fn run_row(self: *Self, row: usize, comptime f: fn (mat: *Self, col: usize, value: t) void) Error!void {
            for (0..self.cols) |col| {
                const value = try self.get(row, col);
                // Safe to call the function on this column because the above call will check the
                // coordinate is valid.
                f(self, col, value);
            }
        }

        pub fn run_col(self: *Self, col: usize, comptime f: fn (mat: *Self, row: usize, value: t) void) Error!void {
            for (0..self.rows) |row| {
                const value = try self.get(row, col);
                // Safe to call the function on this column because the above call will check the
                // coordinate is valid.
                f(self, row, value);
            }
        }

        // Returns if the coordinate provided is invalid.
        fn invalid_coord(self: Self, row: usize, col: usize) bool {
            return row >= self.rows or col >= self.cols;
        }

        /// Pretty prints the matrix. This function uses an arena allocator internally.
        pub fn print(self: Self) Allocator.Error!void {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            var builder = std.ArrayList(u8).init(allocator);
            defer builder.deinit();
            for (0..self.rows) |row| {
                if (row == 0) {
                    try builder.appendSlice("[");
                } else {
                    try builder.appendSlice(" ");
                }

                for (0..self.cols) |col| {
                    const str = blk: {
                        const value = self.get(row, col) catch unreachable;
                        if (col == self.cols - 1) {
                            break :blk try std.fmt.allocPrint(allocator, "{}", .{value});
                        } else {
                            break :blk try std.fmt.allocPrint(allocator, "{}, ", .{value});
                        }
                    };
                    try builder.appendSlice(str);
                }

                if (row == self.rows - 1) {
                    try builder.appendSlice("]\n");
                } else {
                    try builder.appendSlice("\n");
                }
            }
            std.debug.print("{s}", .{try builder.toOwnedSlice()});
        }

        test "Matrix: run_row_col" {
            const alloc = std.testing.allocator;
            const expectEqual = std.testing.expectEqual;

            var m = try Matrix(u8).init(alloc, 2, 2);
            defer m.deinit();

            m.flush(0);
            m.run_row_col(add_one);

            try expectEqual(1, try m.get(0, 0));
            try expectEqual(1, try m.get(0, 1));
            try expectEqual(1, try m.get(1, 0));
            try expectEqual(1, try m.get(1, 1));
        }

        test "Matrix: run_row" {
            const alloc = std.testing.allocator;
            const expectEqual = std.testing.expectEqual;

            var m = try Matrix(u8).init(alloc, 2, 2);
            defer m.deinit();

            m.flush(0);
            try m.run_row(0, add_one_row);

            try expectEqual(1, try m.get(0, 0));
            try expectEqual(0, try m.get(0, 1));
            try expectEqual(1, try m.get(1, 0));
            try expectEqual(0, try m.get(1, 1));
        }

        test "Matrix: run_col" {
            const alloc = std.testing.allocator;
            const expectEqual = std.testing.expectEqual;

            var m = try Matrix(u8).init(alloc, 2, 2);
            defer m.deinit();

            m.flush(0);
            try m.run_col(0, add_one_col);

            try expectEqual(1, try m.get(0, 0));
            try expectEqual(1, try m.get(0, 1));
            try expectEqual(0, try m.get(1, 0));
            try expectEqual(0, try m.get(1, 1));
        }

        test "Matrix: set and get" {
            const alloc = std.testing.allocator;

            var m = try Matrix(u8).init(alloc, 4, 4);
            defer m.deinit();
            try m.set(1, 2, 7);
            try std.testing.expectEqual(7, try m.get(1, 2));
        }

        test "Matrix: get_last" {
            const alloc = std.testing.allocator;

            var m = try Matrix(u8).init(alloc, 4, 4);
            defer m.deinit();

            m.flush(13);

            try m.set(3, 3, 4);

            try std.testing.expectEqual(4, m.get_last());
        }

        test "Matrix: flush" {
            const alloc = std.testing.allocator;

            var m = try Matrix(u8).init(alloc, 4, 4);
            defer m.deinit();
            m.flush(13);
            try std.testing.expectEqual(13, try m.get(0, 0));
            try std.testing.expectEqual(13, try m.get(0, 1));
            try std.testing.expectEqual(13, try m.get(0, 2));
            try std.testing.expectEqual(13, try m.get(0, 3));
            try std.testing.expectEqual(13, try m.get(1, 0));
            try std.testing.expectEqual(13, try m.get(1, 1));
            try std.testing.expectEqual(13, try m.get(1, 2));
            try std.testing.expectEqual(13, try m.get(1, 3));
            try std.testing.expectEqual(13, try m.get(2, 0));
            try std.testing.expectEqual(13, try m.get(2, 1));
            try std.testing.expectEqual(13, try m.get(2, 2));
            try std.testing.expectEqual(13, try m.get(2, 3));
            try std.testing.expectEqual(13, try m.get(3, 0));
            try std.testing.expectEqual(13, try m.get(3, 1));
            try std.testing.expectEqual(13, try m.get(3, 2));
            try std.testing.expectEqual(13, try m.get(3, 3));
        }

        test "Matrix: flush_row" {
            const alloc = std.testing.allocator;

            var m = try Matrix(u8).init(alloc, 3, 3);
            defer m.deinit();
            m.flush(0);

            // Flush row 1 with value 42
            try m.flush_row(1, 42);

            // Check that row 1 was flushed correctly
            try std.testing.expectEqual(42, try m.get(1, 0));
            try std.testing.expectEqual(42, try m.get(1, 1));
            try std.testing.expectEqual(42, try m.get(1, 2));

            // Check that other rows were unaffected (should be default 0)
            try std.testing.expectEqual(0, try m.get(0, 0));
            try std.testing.expectEqual(0, try m.get(2, 0));

            // Test out of range
            try std.testing.expectError(Error.OutOfRange, m.flush_row(3, 42));
        }

        test "Matrix: flush_col" {
            const alloc = std.testing.allocator;

            var m = try Matrix(u8).init(alloc, 3, 3);
            defer m.deinit();
            m.flush(0);

            // Flush column 2 with value 99
            try m.flush_col(2, 99);

            // Check that column 2 was flushed correctly
            try std.testing.expectEqual(99, try m.get(0, 2));
            try std.testing.expectEqual(99, try m.get(1, 2));
            try std.testing.expectEqual(99, try m.get(2, 2));

            // Check that other columns were unaffected (should be default 0)
            try std.testing.expectEqual(0, try m.get(0, 0));
            try std.testing.expectEqual(0, try m.get(0, 1));

            // Test out of range
            try std.testing.expectError(Error.OutOfRange, m.flush_col(3, 99));
        }
        test "Matrix: edge case sizes" {
            const alloc = std.testing.allocator;

            // Test 0xN and Nx0 matrices
            var m1 = try Matrix(u8).init(alloc, 0, 5);
            defer m1.deinit();
            var m2 = try Matrix(u8).init(alloc, 5, 0);
            defer m2.deinit();

            // Test 1x1 matrix
            var m3 = try Matrix(u8).init(alloc, 1, 1);
            defer m3.deinit();
            try m3.set(0, 0, 1);
            try std.testing.expectEqual(1, try m3.get(0, 0));
        }
        test "Matrix: operation consistency" {
            const alloc = std.testing.allocator;
            var m = try Matrix(u8).init(alloc, 3, 3);
            defer m.deinit();

            try m.flush_row(0, 1);
            try m.flush_col(0, 2);
            try m.set(1, 1, 3);

            try std.testing.expectEqual(2, try m.get(0, 0)); // Intersection of row/col flush
            try std.testing.expectEqual(1, try m.get(0, 1)); // Row flush
            try std.testing.expectEqual(2, try m.get(1, 0)); // Col flush
            try std.testing.expectEqual(3, try m.get(1, 1)); // Individual set
        }
    };
}

test "Matrix" {
    _ = Matrix(u2);
}

// Test function
fn add_one(mat: *Matrix(u8), row: usize, col: usize, value: u8) void {
    mat.set(row, col, value + 1) catch unreachable;
}

// Test function
fn add_one_row(mat: *Matrix(u8), row: usize, value: u8) void {
    mat.set(row, 0, value + 1) catch unreachable;
}

// Test function
fn add_one_col(mat: *Matrix(u8), col: usize, value: u8) void {
    mat.set(0, col, value + 1) catch unreachable;
}
