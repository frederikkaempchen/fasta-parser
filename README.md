# fasta_parser
a minimal library for parsing fasta files

## only data type:

```zig
pub fn Read(comptime T: type) type {
  return struct {
    header: Header,
    sequence: Sequence(T), // a Sequence is internally an ArrayList of T.Symbols where T is an Alphabet
  }
}

pub const Header = std.ArrayList(u8);
pub fn Sequence(comptime T: type) type
```
## T is an Alphabet
one can create an own alphabet thus:
```zig
const MyAlphabet = Alphabet("ABCDEFG");
```
the elements in the string are the symbols of the alphabet and must be unique.

## two ways to use the library:

1. ust use the `parseFasta` function and parse the given file into an `ArrayList(Read(T))`
2. use the `FastaParser(T).iterate` function to turn a reader into a `FastaParser(T)` and use the `FastaParser(T).next()` function to iterate through reads until error.EndOfStream is returned

## one can embed the file at comptime
This is useful if one has large files and wants to avoid disk io every time - by using `@embedFile(<relative file path>)` the file is embedded into the binary and is only read once at compiletime.
If one iterates a lot this is nice as zig has incremental compilation and if the file isn't changed it won't need to be read again.
the example times on my pc: 0.112s vs 0.006 - not a great benchmark as it is a tiny file but still...

## TODO
- [ ] lowercase
- [ ] full IUPAC base alphabet
- [ ] partial reads iterator api that guarantees a maximum of allocations for each next function call
- [ ] comptime Reads with known sequence size and header size through `@embedFile`
