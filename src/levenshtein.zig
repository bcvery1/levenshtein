const std = @import("std");

const matrix = @import("matrix.zig");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub const Error = error{
    EmptyDictionary,
} || matrix.Error || Allocator.Error;

pub fn distance(comptime t: type, allocator: Allocator, target_word: []const t, dict_word: []const t) Error!usize {
    const rows = target_word.len + 1;
    const cols = dict_word.len + 1;

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
                if (target_word[prev_row] == dict_word[prev_col]) {
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

// Helper function to set the first row to the column index, and the first column to the row index.
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
    try expectEqual(3, try distance(u8, alloc, "foo", ""));
    try expectEqual(3, try distance(u8, alloc, "", "foo"));
}

/// Customisable options to set when performing distance calculations.
pub const Opts = struct {
    /// If set to true, the dictionary word will be shortened until it is no longer than the target
    /// word. This is a no-op if the target word is longer than, or the same length as, the
    /// dictionary.
    ///
    /// This can be useful when trying to 'auto-complete', as it avoids suggesting words which are
    /// closer simply because the length matches.
    shorten_dict_words: bool = false,
};

/// Sorts the provided array in place, where the first element is the shortest Levenshtein distance
/// to the word.
pub fn sort_in_place(comptime t: type, allocator: Allocator, word: []const t, dictionary: [][]const t, opts: Opts) Error!void {
    if (dictionary.len == 0) return Error.EmptyDictionary;

    var items = try allocator.alloc(DictItem(t), dictionary.len);
    defer allocator.free(items);

    for (0.., dictionary) |i, dict_word| {
        items[i] = try DictItem(t).init(allocator, word, dict_word, i, opts);
    }

    std.sort.heap(DictItem(t), items, {}, DictItem(t).less_than);
    for (0.., items) |i, item| {
        dictionary[i] = item.item;
    }
}

/// Sorts the provided array, returning copy of the sorted array, preserving the original, where the
/// first element of the returned array is the shortest Levenshtein distance to the word.
///
/// The caller is responsible for freeing the returned memory.
pub fn sort(comptime t: type, allocator: Allocator, word: []const t, dictionary: [][]const t, opts: Opts) Error![][]const t {
    const dictionary_copy = try allocator.dupe([]const t, dictionary);
    try sort_in_place(t, allocator, word, dictionary_copy, opts);
    return dictionary_copy;
}

test "sort" {
    const alloc = std.testing.allocator;
    const expectEqualStrings = std.testing.expectEqualStrings;

    var dict = [_][]const u8{ "bar", "bazbar", "foo" };
    const word = "fo";

    const cp = try sort(u8, alloc, word, &dict, .{});
    defer alloc.free(cp);

    // Check the copy has been reordered
    try expectEqualStrings("foo", cp[0]);
    try expectEqualStrings("bar", cp[1]);
    try expectEqualStrings("bazbar", cp[2]);

    // Check the original is unchanged
    try expectEqualStrings("bar", dict[0]);
    try expectEqualStrings("bazbar", dict[1]);
    try expectEqualStrings("foo", dict[2]);
}

test "sort: empty dictionary" {
    const alloc = std.testing.allocator;
    const expectError = std.testing.expectError;

    var dict = [_][]const u8{};
    const word = "foo";

    try expectError(Error.EmptyDictionary, sort(u8, alloc, word, &dict, .{}));
}

fn DictItem(comptime t: type) type {
    return struct {
        const Self = @This();

        item: []const t = undefined,
        // Value an arbitrary large number.
        l_dist: usize = 1000000,
        // The index of the word in the original dictionary.
        index: usize = 0,

        pub fn init(allocator: Allocator, word: []const t, dict_word: []const t, index: usize, opts: Opts) Error!Self {
            // comp_word is the word by which we do the comparison, it has undergone preprocessing
            const comp_word = blk: {
                var cw = dict_word;
                if (opts.shorten_dict_words and word.len < cw.len) {
                    cw = cw[0..word.len];
                }
                break :blk cw;
            };
            return Self{
                .item = dict_word,
                .l_dist = try distance(t, allocator, word, comp_word),
                .index = index,
            };
        }

        pub fn less_than(_: void, lhs: Self, rhs: Self) bool {
            return lhs.l_dist < rhs.l_dist;
        }
    };
}

/// Returns the 'count' number of closest matches from the dictionary to 'word' according to
/// Levenshtein distance.
///
/// This function mutates the dictionary in place.
pub fn closest_values(comptime t: type, allocator: Allocator, word: []const t, dictionary: [][]const t, count: usize, opts: Opts) Error![][]const t {
    try sort_in_place(t, allocator, word, dictionary, opts);
    return dictionary[0..count];
}

/// Returns the closest match from the dictionary to 'word' according to the Levenshtein distance.
/// If there are multiple matches of the same distance, this function will return one of them
/// arbitrarily.
///
/// This function mutates the dictionary in place.
pub fn closest(comptime t: type, allocator: Allocator, word: []const t, dictionary: [][]const t, opts: Opts) Error![]const t {
    const v = try closest_values(t, allocator, word, dictionary, 1, opts);
    return v[0];
}

test "closest" {
    const alloc = std.testing.allocator;
    const expectEqualStrings = std.testing.expectEqualStrings;

    var dict = [_][]const u8{ "bar", "bazbar", "foo" };
    const word = "fo";

    try expectEqualStrings("foo", try closest(u8, alloc, word, &dict, .{}));
}

test "closest: shorten dict word" {
    const alloc = std.testing.allocator;
    const expectEqualStrings = std.testing.expectEqualStrings;

    var dict = [_][]const u8{ "foobar", "bar", "bazy" };
    const word = "foo";

    try expectEqualStrings("foobar", try closest(u8, alloc, word, &dict, .{ .shorten_dict_words = true }));
    try expectEqualStrings("bar", try closest(u8, alloc, word, &dict, .{ .shorten_dict_words = false }));
}
