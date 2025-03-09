const std    = @import("std");
const ally   = std.heap.page_allocator;
const fs     = std.fs;
const stdout = std.io.getStdOut().writer();
const print  = std.debug.print;



const colors = .{
    .blue  = "\x1B[34m",
    .green = "\x1B[32m",
    .red   = "\x1B[31m",
    .bold  = "\x1B[1m",
    .reset = "\x1B[39m",
};

fn switch_color(color: []const u8) !void {
    try stdout.print("{s}", .{ color });
}

const DirStat = struct {
    size:         u64,
    entryCount:   u32,
    hiddenCount:  u32,
    // File Kinds
    dirCount:     u32,
    fileCount:    u32,
    symlinkCount: u32,

    const Self = @This();

    fn empty() Self {
        return .{
            .size         = 0,
            .entryCount   = 0,
            .hiddenCount  = 0,
            .dirCount     = 0,
            .fileCount    = 0,
            .symlinkCount = 0,
        };
    }

    fn getFileSize(filename: []const u8) !u64 {
        const path = try fs.realpathAlloc(ally, filename);
        defer ally.free(path);

        const file = try fs.openFileAbsolute(path, .{});
        defer file.close();

        return (try file.stat()).size;
    }

    fn traverseDir(path_rel: []const u8) !Self {
        var info = Self.empty();

        const path = try fs.realpathAlloc(ally, path_rel);
        defer ally.free(path);

        const dir = try fs.openDirAbsolute(path, .{ .iterate=true });

        var walker = try dir.walk(ally);
        defer walker.deinit();

        info.size += (try dir.stat()).size;

        while (try walker.next()) |entry| {
            const str = try std.fmt.allocPrint(ally, "{s}{s}", .{ path_rel, entry.path });
            defer ally.free(str);

            info.size += try Self.getFileSize(str);

            const Kind = fs.Dir.Entry.Kind;
            switch (entry.kind) {
                Kind.directory => info.dirCount     += 1,
                Kind.sym_link  => info.symlinkCount += 1,
                Kind.file      => info.fileCount    += 1,
                else => {},
            }

            info.entryCount += 1;
            if (entry.basename[0] == '.') {
                info.hiddenCount += 1;
            }
        }

        return info;

    }

};

pub fn main() !void {

    const dirname = "./test/";
    const info = try DirStat.traverseDir(dirname);

    const fmt = "Statistics from ";
    try stdout.print("{s}{s}{s}{s}{s}\n", .{ fmt, colors.bold, colors.blue, dirname, colors.reset });

    try switch_color(colors.bold);
    try switch_color(colors.blue);
    for (0..fmt.len + dirname.len) |_| {
        try stdout.print("-", .{});
    }
    try stdout.print("\n", .{});
    try switch_color(colors.reset);

    try stdout.print("{s}{s}-> {s}", .{ colors.bold, colors.red, colors.reset });
    try stdout.print("Size: {} KiB\n", .{ info.size / 1024 });

    try stdout.print("{s}{s}-> {s}", .{ colors.bold, colors.red, colors.reset });
    try stdout.print("{} Files\n", .{ info.entryCount  });

    try stdout.print("{s}{s}-> {s}", .{ colors.bold, colors.red, colors.reset });
    try stdout.print("{} Hidden\n", .{ info.hiddenCount });

}
