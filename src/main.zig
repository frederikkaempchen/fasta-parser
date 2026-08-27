const std = @import("std");
const Io = std.Io;

const fasta_parser = @import("parser.zig");
const parseFasta = fasta_parser.parseFasta;
const Read = fasta_parser.Read;
const Header = fasta_parser.Header;

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    const root = std.Io.Dir.cwd();
    std.debug.print("reading file: {s}\n", .{args[2]});
    const file = try root.openFile(io, args[2], .{ .mode = .read_only });
    defer file.close(io);

    const buffer = try arena.alloc(u8, 100000);
    defer arena.free(buffer);
    var fr = file.reader(io, buffer);

    const clk: Io.Clock = .cpu_process;

    const t1: std.Io.Timestamp = .now(io, clk);

    const reads = try parseFasta(&fr.interface, arena);

    const t2: std.Io.Timestamp = .now(io, clk);

    std.debug.print("time needed: {}\n", .{@as(f64, @floatFromInt(t2.nanoseconds - t1.nanoseconds)) / std.math.pow(f64, 10, 6)});

    std.debug.print("{s}", .{reads.items[0].header.items});

    // for (reads.items) |read| {
    //     std.debug.print("{s}\n", .{read.header.items});
    //     for (read.sequence.bases.items) |base| {
    //         const char: u8 = switch (base) {
    //             .A => 'A',
    //             .C => 'C',
    //             .G => 'G',
    //             .T => 'T',
    //         };
    //         std.debug.print("{c}", .{char});
    //     }
    //     std.debug.print("\n", .{});
    // }
}
