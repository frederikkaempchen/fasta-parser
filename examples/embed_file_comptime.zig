const std = @import("std");
const Io = std.Io;

const fasta_parser = @import("fasta_parser");
const parseFasta = fasta_parser.parseFasta;
const Read = fasta_parser.Read;
const Base = fasta_parser.Base;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    const file_sub_path = "./test.fasta";
    const embedded = @embedFile(file_sub_path);
    var fr = Io.Reader.fixed(embedded[0 .. embedded.len - 1]);

    std.debug.print("reading file examples/test.fasta - but not really, the file is embedded as array into the binary of this example at compile time :)\n\n", .{});

    const clk: Io.Clock = .real; // wallclock
    const t1: std.Io.Timestamp = .now(io, clk);

    // read all reads (a read is header + sequence) into an ArrayList of Reads allocated on the heap
    const reads = try parseFasta(&fr, arena, Base);

    const t2: std.Io.Timestamp = .now(io, clk);

    std.debug.print("time needed: {}\n\n", .{@as(f64, @floatFromInt(t2.nanoseconds - t1.nanoseconds)) / std.math.pow(f64, 10, 6)});

    for (reads.items) |read| {
        std.debug.print("{s}\n", .{read.header.items});
        for (read.sequence.sequence.items) |el| {
            std.debug.print("{c}", .{Base.toChar(el)});
        }
        std.debug.print("\n\n", .{});
    }
}
