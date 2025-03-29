const std = @import("std");

const lev = @import("lev");

var names = [_][]const u8{
    "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason", "Isabella", "Riley",
};

fn get_input_from_user(allocator: std.mem.Allocator) ![]const u8 {
    const in = std.io.getStdIn();
    var buf = std.io.bufferedReader(in.reader());

    var r = buf.reader();

    std.debug.print("Please enter a name, I will check it against my list: ", .{});

    var msg_buf: [1024]u8 = undefined;
    const input = try r.readUntilDelimiter(&msg_buf, '\n');
    const ret = allocator.dupe(u8, input);
    return ret;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const guess = try get_input_from_user(allocator);
    defer allocator.free(guess);

    // Use shorten dictionary words here so the input length is matched to the dictionary words.
    // This prevents matching 'Ava' when the user typed in 'Mas' for example, just because they're
    // both three letters long.
    const closest_name = try lev.closest(allocator, guess, &names, .{ .shorten_dict_words = true, .ignore_case = true });

    std.debug.print("I think you mean: '{s}'\n", .{closest_name});
}
