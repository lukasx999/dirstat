const std   = @import("std");
const ally  = std.heap.page_allocator;
const fs    = std.fs;
const print = std.debug.print;


fn openDir(dir: []const u8) !fs.Dir {
    const path = try fs.realpathAlloc(ally, dir);
    defer ally.free(path);

    return fs.openDirAbsolute(path, .{ .iterate=true });
}

const DirInfo = struct {
    entryCount:   u32,
    hiddenCount:  u32,
    dirCount:     u32,
    fileCount:    u32,
    symlinkCount: u32,

    const Self = @This();

    fn new() Self {
        return .{
            .entryCount   = 0,
            .hiddenCount  = 0,
            .dirCount     = 0,
            .fileCount    = 0,
            .symlinkCount = 0,
        };
    }

    fn getDirInfo(dir: fs.Dir) !Self {
        var walker = try dir.walk(ally);
        defer walker.deinit();

        var info = Self.new();

        while (try walker.next()) |entry| {

            const Kind = fs.Dir.Entry.Kind;
            switch (entry.kind) {
                Kind.directory => info.dirCount     += 1,
                Kind.sym_link  => info.symlinkCount += 1,
                Kind.file      => info.fileCount    += 1,
                else => {},
            }

            info.entryCount += 1;
            if (entry.basename[0] == '.')
            info.hiddenCount += 1;
        }

        return info;

    }

};


pub fn main() !void {

    var dir = try openDir("./test/");
    defer dir.close();

    const info = try DirInfo.getDirInfo(dir);

    print("info: {}\n", .{ info });


}
