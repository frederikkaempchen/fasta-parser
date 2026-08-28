# fasta_parser
a minimal library for parsing fasta files

## only data type:

```zig
pub const Read = struct {
  header: Header,
  sequence: Sequence,
}

pub const Header = std.ArrayList(u8);
pub const Sequence = std.ArrayList(u8);
```

## supported bases: A, C, T, G, N

## two ways to use the library:

1. just use the `parseFasta` function and parse the given file into an `ArrayList(Read)`
2. use the `FastaParser.iterate` function to turn a reader into a `FastaParser` and use the `FastaParser.next()` function to iterate through reads until error.EndOfStream is returned


## TODO
- [ ] lowercase
- [ ] full IUPAC base alphabet
- [ ] compression (only 4 bits needed for full IUPAC alphabet)
- [ ] partial reads iterator api that guarantees a maximum of allocations for each next function call
