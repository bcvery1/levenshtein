# Levenshteien
Implementation of the Levenshtein Distance algorithm in Zig.

## Getting started

### Adding as dependency

First use the following command to add the dependency to your `build.zig.zon`:
```sh
zig fetch --save https://github.com/bcvery1/levenshtein/archive/refs/tags/[VERSION].tar.gz
```

You may wish to save the library with a specific name, for example:
```sh
zig fetch --save=lev https://github.com/bcvery1/levenshtein/archive/refs/tags/0.1.0.tar.gz
```
We'll use the name `lev` the next excerpt.

Next you'll want to add the following to your `build.zig` file:
```zig
const levenshtein = b.dependency("lev", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("lev", levenshtein.module("lev");
```

You can then import and use the library with `const lev = @import("lev");`

### Basic usage

This simple example shows how to get the closest word to the user inputed word from a static dictionary:
```zig
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
    try lev.sort_in_place(allocator, word1, &strs, .{});
    assert(std.mem.eql(u8, "ale", strs[0]));

    const word2 = "vegeta";
    try lev.sort_in_place(allocator, word2, &strs, .{});
    assert(std.mem.eql(u8, "vegetables", strs[0]));
}
```

**For more examples on usage, take a look at the [examples](./) directory.**

## Licence
[MIT](./LICENSE)
