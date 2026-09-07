const std = @import("std");
const Reader = std.Io.Reader;
const Allocator = std.mem.Allocator;
const Alphabet = @import("alphabet").Alphabet;

/// T is the element type of the sequence - Base and AminoAcid are implemented
pub fn Read(comptime T: type) type {
    return struct {
        header: Header,
        sequence: Sequence(T),

        const Self = @This();

        /// parses sequence buffer and appends bases to sequence
        pub fn appendSequenceBuffer(self: *Self, gpa: Allocator, buffer: []u8) (Allocator.Error || error{InvalidCharacter})!void {
            try self.sequence.appendBuffer(gpa, buffer);
        }
    };
}

pub const Header = std.ArrayList(u8);

pub const Base = Alphabet("ACTGN");

pub const AminoAcid = Alphabet("MSEKIWVLAQYTFGPNRDHCU");

pub fn Sequence(comptime T: type) type {
    return struct {
        sequence: std.ArrayList(T.Symbol),

        const Self = @This();

        pub fn fromString(gpa: Allocator, sequence: []const u8) error{InvalidCharacter}!Self {
            var bases: std.ArrayList(T.Symbol) = try .initCapacity(gpa, sequence.len);

            for (sequence) |elem| {
                bases.appendAssumeCapacity(try T.fromChar(elem));
            }

            return .{ .sequence = bases };
        }

        pub fn appendBuffer(self: *Self, gpa: Allocator, buffer: []u8) (Allocator.Error || error{InvalidCharacter})!void {
            try self.sequence.ensureUnusedCapacity(gpa, buffer.len);
            for (buffer) |el| {
                if (el == '\n') continue;
                self.sequence.appendAssumeCapacity(T.fromChar(el) catch |err| {
                    std.log.err("invalid character: {c}\n", .{el});
                    return err;
                });
            }
        }

        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.sequence.deinit(gpa);
        }
    };
}

pub const NucSequence = Sequence(Base);

pub const ProtSequence = Sequence(AminoAcid);

pub const FastaParseError = error{
    EmptyFile,
    InvalidHeader,
    HeaderWithoutSequence,
    InvalidCharacter,
};

/// T is the element type of a sequence - Base and AminoAcid are implemented
pub fn FastaParser(comptime T: type) type {
    return struct {
        reader: *Reader,

        const Self = @This();

        pub fn iterate(reader: *Reader) Self {
            return .{ .reader = reader };
        }

        pub fn next(self: *Self, gpa: Allocator) (Allocator.Error || Reader.Error || FastaParseError)!Read(T) {
            var current_read: Read(T) = .{ .header = try .initCapacity(gpa, 0), .sequence = .{ .sequence = .empty } };
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
}

/// T is the type of an element of a sequence - AminoAcid and Base are implemented
pub fn parseFasta(reader: *Reader, gpa: Allocator, comptime T: type) (Allocator.Error || Reader.Error || FastaParseError)!std.ArrayList(Read(T)) {
    var reads: std.ArrayList(Read(T)) = try .initCapacity(gpa, 0);
    errdefer reads.deinit(gpa);

    var fasta_reader = FastaParser(T).iterate(reader);
    while (true) {
        const current_read = fasta_reader.next(gpa) catch |err| switch (err) {
            error.EndOfStream => return reads,
            else => return err,
        };
        try reads.append(gpa, current_read);
    }
}
