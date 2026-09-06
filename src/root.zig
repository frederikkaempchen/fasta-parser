const std = @import("std");
const Reader = std.Io.Reader;
const Allocator = std.mem.Allocator;

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

pub const Base = enum(u3) {
    A = 0,
    C = 1,
    T = 2,
    G = 3,
    N = 4,

    const chars: [5]u8 = .{ 'A', 'C', 'T', 'G', 'N' };

    pub fn fromChar(char: u8) error{InvalidCharacter}!Base {
        const lookup: [256]?Base = comptime blk: {
            var table: [256]?Base = .{null} ** 256;
            for (chars, 0..) |c, i| {
                table[c] = @enumFromInt(i);
            }
            break :blk table;
        };
        return lookup[char] orelse error.InvalidCharacter;
    }

    pub fn intoChar(elem: Base) u8 {
        return chars[@intFromEnum(elem)];
    }
};

pub const AminoAcid = enum(u5) {
    M = 0,
    S = 1,
    E = 2,
    K = 3,
    I = 4,
    W = 5,
    V = 6,
    L = 7,
    A = 8,
    Q = 9,
    Y = 10,
    T = 11,
    F = 12,
    G = 13,
    P = 14,
    N = 15,
    R = 16,
    D = 17,
    H = 18,
    C = 19,
    U = 20,

    const chars: [21]u8 = .{
        'M', 'S', 'E', 'K', 'I',
        'W', 'V', 'L', 'A', 'Q',
        'Y', 'T', 'F', 'G', 'P',
        'N', 'R', 'D', 'H', 'C',
        'U',
    };

    pub fn fromChar(char: u8) error{InvalidCharacter}!AminoAcid {
        const lookup: [256]?AminoAcid = comptime blk: {
            var table: [256]?AminoAcid = .{null} ** 256;

            for (chars, 0..) |c, i| {
                table[c] = @enumFromInt(i);
            }

            break :blk table;
        };

        return lookup[char] orelse error.InvalidCharacter;
    }

    pub fn intoChar(elem: AminoAcid) u8 {
        return chars[@intFromEnum(elem)];
    }
};

pub fn Sequence(comptime T: type) type {
    return struct {
        sequence: std.ArrayList(T),

        const Self = @This();

        pub fn fromString(gpa: Allocator, sequence: []const u8, fromChar: fn (u8) error{InvalidCharacter}!T) !Self {
            var bases: std.ArrayList(T) = try .initCapacity(gpa, sequence.len);

            for (sequence) |elem| {
                bases.appendAssumeCapacity(try fromChar(elem));
            }

            return .{ .sequence = bases };
        }

        pub fn appendBuffer(self: *Self, gpa: Allocator, buffer: []u8) (Allocator.Error || error{InvalidCharacter})!void {
            try self.sequence.ensureUnusedCapacity(gpa, buffer.len);
            for (buffer) |el| {
                if (el == '\n') continue;
                self.sequence.appendAssumeCapacity(try T.fromChar(el));
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
