1. What it is
Yet another Lempel-Ziv cruncher for the 6502.

Specifically it is a traditional bit-packed LZ coder which has been optimized for decrunching speed at the expense of code size. Achieving decent compression ratios and high throughput by nearly keeping up with a 1541 loader.

2. What it isn't
· Tiny. The decruncher is nearly a page long.
· It will not (yet) generate self-extracting executables.
· It is inefficient at in-place decompression. The worst-case safety-zone is larger than a page due to literals copied in reverse.
· It is purely a cross-development tool. There is no native C64 cruncher.h
· The decruncher relies on self-modifying code and will not run from ROM (NES cartridges, etc).
· It is unsuitable for very slow (datasette) or very fast (cartridge) loaders. Try Exomizer or LZWVL.

3. Credits
This project is a fork off of HCL's excellent ByteBoozer, from which the basic encoding has been inherited.
Note: Any gains in compression ratio over BB are solely due to improved parsing and tweaked offset lengths

Bitbreaker has made several important contributions to the project; including some critical bug fixes to the project, the non-streaming version of the decruncher as well as other features I have yet to incorporate.

4. Using the decruncher
The regular decruncher routine may be found in "decrunch.asm".

This decruncher operates by consuming a single-page lz_sector buffer and then invoking the user-supplied lz_fetch_sector callback to replenish it once it has run out. Normally this involves having lz_fetch_sector fetch the next sector from the floppy.
Within the decruncher the X register points to the next available byte and the next page is fetched once it overflows. To skip the track/sector links X may be initialized and reset to two instead of zero. To perform in-memory decompression the sector buffers may be relocated by patching the lz_sector_ptr1/2/3 pointers.
Note that the first sector must be available when beginning the decompression.

The code also requires four bytes of zero-page storage:
· lz_dst - A 16-bit pointer to the output address.
· lz_bits - An internal shift register.
· lz_scratch - The general scratchpad.

Once these have been set up and X points to the first data byte the decompression function, lz_decrunch, may be called to unpack the entire file.

Note that the code does not rely on any illegal opcodes and should be reasonably assembler-agnostic.

Please see the code and examples for further details.

5. Streaming
It is occasionally useful not to load large files as a whole but rather continually stream in only small sections into memory. Consider unpacking a file larger than memory, displaying a huge animation or scrolling in a continuous bitmap.

This can be achieved by decompressing to a smaller sliding window, that is a ring buffer in which the last N bytes of the unpacked file are temporarily stored during decrunching. The larger the window the further back matches can be made, thus improving the compression ratio.

To support this there is an alternate version of the decruncher: "streaming.asm".

When streaming it is often useful to fill up the compression window in the background, providing buffering while the foreground code consumes data at a leisurely pace. To support this the streaming version has a slightly different interface where the lz_decrunch function renders one page of data per call, returning with carry cleared at the end of a file.
In practice this would typically involve having the the main code continually read data until it reaches data not yet read by the consumer, with the consumer running during the interrupts and pausing when catching up to lz_dst.

The cruncher must be informed of the window size (via the --window N switch) else it would not know to avoid distant matches.

The user is responsible for manually handling wrapping around the window edges. In part this means incrementing and wrapping the lz_dst MSB between lz_decrunch calls, but matches wrapping around the window edges must also be supported. The latter must be entered into "streaming.asm" (see the arrow), typically with an AND/ORA of the address MSB for aligned power-of-two windows.

One complication is that the output of lz_decrunch may partially cross into the next page, requiring an extra page of safety space to avoid inadvertently catching up to the consumer. It will not wrap around the end of the window however.

A difference from the regular cruncher is that lz_bits must be initialized to $80 on startup to mark it as empty.

6. Using the cruncher
The cruncher is a command-line utility intended to be integrated into a build chain. A pre-compiled Win32 binary has been included and the ANSI C code should compile with minimal tweaking on any modern platforms.

The file to be compressed is a required argument, in addition the following switches are available:
· -o: Specify the output file name. By default the input file with an .lz extension.
· --window: Specify the window size for with streaming decompression.
· --per-page: Force the windowed encoding for regular files. This is handy when combining both types of data.
· --cut-input: Only specific segment of the file.
· --offset-lengths: Use an alternate set of offset lengths. See next section.
· --emit-offset-lengths: Generate the appropriate decruncher tables for the chosen offset lengths. See next section.
· --statistics: Display some basic information about the types of matches made.

The cruncher performance may degrade for very long sequences of repeated data. This may be worked around in future versions if it should prove to be a problem.

7. Offset what?
To save space the cruncher uses a varying number of bits to encode match offsets, that is how far back in the file a match is. A two-bit prefix to each match selects one out of four possible bit lengths. A separate ("short") set is used solely for the shortest two-byte matches as these only pay off with short offsets.

Unfortunately the optimum set depends on the type of file. Clearly a 15-bit offset is wasted on a 1 kB file.

To squeeze out that extra bit of compression it is possible to manually select a non-standard set via a command line switch and by replacing some table at the end of the decruncher. The default values are equivalent to specifying "--offset-lengths 3/6/8/10:4/7/10/13"; corresponding to 3, 6, 8 and 10-bit 2-byte offsets and 4, 7, 10 and 13-bit offsets for longer matches.
In addition the appropriate tables for the crunchers are generated through the "--emit-offset-lengths" option.

Note that the farthest possible offset is actually larger than the bit count since selecting a longer code implies that the offset does not lie within any of the shorter length options. Hence the default coding can reach up to 2^4+2^7+2^10+2^13=9,360 bytes back.

Sadly there is no automatic way of optimizing the selection over a set of files or loading the tables dynamically.

8. Gotchas
· Lowercase *.prg files are interpreted as CBM files with a two-byte header, everything else is binary.
· Paged/windowed files must be decompressed to the same page/window offset as that at which they were originally compressed. As specified by the PRG header.
· The carry flag must be preserved high after lz_fetch_sector and even actively raised for the streaming version.
· The lz_bits variable must be initialized to $80 before the streaming verion of lz_decrunch.

/Johan Forslöf (doynax at gmail dot com)
