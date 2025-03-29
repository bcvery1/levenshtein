const std = @import("std");

const lev = @import("lev");

const assert = std.debug.assert;

var strs = [_][]const u8{
    "bread",
    "vegetables",
    "cheese",
    "ale",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const word1 = "a";
    try lev.sort_in_place(u8, allocator, word1, &strs, .{});
    assert(std.mem.eql(u8, "ale", strs[0]));

    const word2 = "vegeta";
    try lev.sort_in_place(u8, allocator, word2, &strs, .{});
    assert(std.mem.eql(u8, "vegetables", strs[0]));
}
