const std = @import("std");
const Reader = std.Io.Reader;
const Allocator = std.mem.Allocator;

pub const Read = struct {
    header: Header,
    sequence: Sequence,

    /// parses sequence buffer and appends bases to sequence
    pub fn appendSequenceBuffer(self: *Read, gpa: Allocator, buffer: []u8) (Allocator.Error || error{InvalidSequence})!void {
        try self.sequence.ensureUnusedCapacity(gpa, buffer.len);
        for (buffer) |el| {
            if (el == '\n') continue;
            if (is_base[el]) self.sequence.appendAssumeCapacity(el) else return error.InvalidSequence;
        }
    }
};

pub const Header = std.ArrayList(u8);

pub const Sequence = std.ArrayList(u8);

pub const Base: [5]u8 = .{ 'A', 'C', 'T', 'G', 'N' };

const is_base: [256]bool = blk: {
    var table: [256]bool = .{false} ** 256;
    for (Base) |b| table[b] = true;
    break :blk table;
};

pub const FastaParseError = error{
    EmptyFile,
    InvalidHeader,
    HeaderWithoutSequence,
    InvalidSequence,
};

pub const FastaParser = struct {
    reader: *Reader,

    pub fn iterate(reader: *Reader) FastaParser {
        return .{ .reader = reader };
    }

    pub fn next(self: *FastaParser, gpa: Allocator) (Allocator.Error || Reader.Error || FastaParseError)!Read {
        var current_read: Read = .{ .header = try .initCapacity(gpa, 0), .sequence = try .initCapacity(gpa, 0) };
        errdefer current_read.header.deinit(gpa);
        errdefer current_read.sequence.deinit(gpa);

        var reader = self.reader;

        if (reader.bufferedLen() == 0) {
            try reader.fillMore();
        }

        if (reader.buffered()[0] != '>') return error.InvalidHeader;
        reader.toss(1);

        var buf: []u8 = reader.buffered();

        // parse header
        while (true) {
            const maybe_idx = std.mem.findScalar(u8, buf, '\n');

            if (maybe_idx == null) {
                try current_read.header.appendSlice(gpa, buf);
                reader.tossBuffered();
                reader.fillMore() catch |err| switch (err) {
                    error.EndOfStream => return error.HeaderWithoutSequence,
                    else => return err,
                };
                buf = reader.buffered();
            } else {
                try current_read.header.appendSlice(gpa, buf[0..maybe_idx.?]);
                reader.toss(maybe_idx.? + 1); // 0..maybe_idx inclusive to toss the \n
                buf = reader.buffered();
                break;
            }
        }

        // parse sequence
        while (true) {
            const maybe_idx = std.mem.findScalar(u8, buf, '>');

            if (maybe_idx == null) {
                try current_read.appendSequenceBuffer(gpa, buf);
                reader.tossBuffered();
                reader.fillMore() catch |err| switch (err) {
                    error.EndOfStream => break, // EOS only occurs when fillMore filled zero bytes
                    else => return err,
                };
                buf = reader.buffered();
            } else {
                try current_read.appendSequenceBuffer(gpa, buf[0..maybe_idx.?]);
                reader.toss(maybe_idx.?); // don't toss '>' - needed for validation in next iter
                break;
            }
        }
        return current_read;
    }
};

pub fn parseFasta(reader: *Reader, gpa: Allocator) (Allocator.Error || Reader.Error || FastaParseError)!std.ArrayList(Read) {
    var reads: std.ArrayList(Read) = try .initCapacity(gpa, 0);
    errdefer reads.deinit(gpa);

    var fasta_reader = FastaParser.iterate(reader);
    while (true) {
        const current_read = fasta_reader.next(gpa) catch |err| switch (err) {
            error.EndOfStream => return reads,
            else => return err,
        };
        try reads.append(gpa, current_read);
    }
}
