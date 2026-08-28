const std = @import("std");
const Io = std.Io;

const fasta_parser = @import("fasta_parser");
const parseFasta = fasta_parser.parseFasta;
const Read = fasta_parser.Read;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    const cwd = std.Io.Dir.cwd();
    const file_sub_path = "examples/test.fasta";

    const file = try cwd.openFile(io, file_sub_path, .{ .mode = .read_only });
    defer file.close(io);

    var file_path: [1024]u8 = undefined;

    const file_path_size = try file.realPath(io, &file_path);
    std.debug.print("reading file: {s}\n\n", .{file_path[0..file_path_size]});

    // create file reader with adequately sized buffer - smaller buffer means more syscalls for filling that buffer
    // (and for longer sequences also more allocation syscalls)
    const buffer = try arena.alloc(u8, 4096);
    defer arena.free(buffer);
    var fr = file.reader(io, buffer);

    const clk: Io.Clock = .real; // wallclock

    const t1: std.Io.Timestamp = .now(io, clk);

    // read all reads (a read is header + sequence) into an ArrayList of Reads allocated on the heap
    const reads = try parseFasta(&fr.interface, arena);

    const t2: std.Io.Timestamp = .now(io, clk);

    std.debug.print("time needed: {}\n\n", .{@as(f64, @floatFromInt(t2.nanoseconds - t1.nanoseconds)) / std.math.pow(f64, 10, 6)});

    for (reads.items) |read| {
        std.debug.print("{s}\n", .{read.header.items});
        std.debug.print("{s}\n\n", .{read.sequence.items});
    }
}
