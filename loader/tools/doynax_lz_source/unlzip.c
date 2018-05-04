#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _MSC_VER
#	pragma comment(linker, "/OPT:NOWIN98")
#endif

#define SHOW_STATS 0
#define SHOW_TRACE 0

enum {
	RUN_LIMIT = 0x100,

	SHORT_BITS_A = 3,
	SHORT_BITS_B = 6,
	SHORT_BITS_C = 8,
	SHORT_BITS_D = 10,

	LONG_BITS_A = 4,
	LONG_BITS_B = 6,
	LONG_BITS_C = 9,
	LONG_BITS_D = 12,
};

static signed char shift = 0x80U;

#if SHOW_STATS
static unsigned
	short_freq[4],
	long_freq[4],
	literal_bytes,
	literal_runs,
	match_bytes,
	match_count,
	offset_bits;
#endif

static unsigned getbyte(void) {
	signed value = getchar();

	if(value == EOF) {
		fprintf(stderr, "error: unexpected end of file\n");
		exit(EXIT_FAILURE);
	}

	return value;
}

static unsigned getbit(void) {
	unsigned bit;

	bit = (shift < 0);
	shift <<= 1;

	if(!shift) {
		shift = getbyte();
		bit = (shift < 0);
		shift = (shift << 1) + 1;
	}

	return bit;
}

unsigned decode_literals(void) {
	unsigned length = 1;

	while(!getbit()) {
		length <<= 1;
		length += getbit();
	}

	return length;
}

struct match {
	unsigned offset;
	unsigned length;
} decode_match(void) {
	enum {
		SHORT_BASE_A = 1,
		SHORT_BASE_B = (1 << SHORT_BITS_A) + SHORT_BASE_A,
		SHORT_BASE_C = (1 << SHORT_BITS_B) + SHORT_BASE_B,
		SHORT_BASE_D = (1 << SHORT_BITS_C) + SHORT_BASE_C,

		LONG_BASE_A = 1,
		LONG_BASE_B = (1 << LONG_BITS_A) + LONG_BASE_A,
		LONG_BASE_C = (1 << LONG_BITS_B) + LONG_BASE_B,
		LONG_BASE_D = (1 << LONG_BITS_C) + LONG_BASE_C
	};

	static const struct {
		unsigned bits;
		unsigned base;
	} short_tab[] = {
		{ SHORT_BITS_A, SHORT_BASE_A },
		{ SHORT_BITS_B, SHORT_BASE_B },
		{ SHORT_BITS_C, SHORT_BASE_C },
		{ SHORT_BITS_D, SHORT_BASE_D },
	}, long_tab[] = {
		{ LONG_BITS_A, LONG_BASE_A },
		{ LONG_BITS_B, LONG_BASE_B },
		{ LONG_BITS_C, LONG_BASE_C },
		{ LONG_BITS_D, LONG_BASE_D },
	};

	unsigned prefix;
	unsigned length;
	signed offset;
	unsigned bits;
	unsigned base;
	struct match result;

	length = getbit();
	prefix = getbit() << 1;
	prefix += getbit();

	if(length) {
		bits = short_tab[prefix].bits;
		base = short_tab[prefix].base;

#		if SHOW_STATS
		++short_freq[prefix];
#		endif
	} else {
		bits = long_tab[prefix].bits;
		base = long_tab[prefix].base;

#		if SHOW_STATS
		++long_freq[prefix];
#		endif
	}

#	if SHOW_STATS
	offset_bits += bits;
#	endif

	offset = -1;

	while(bits & 7) {
		offset <<= 1;
		offset += getbit();
		--bits;
	}

	if(bits) {
		offset <<= 8;
		offset += getbyte();
	}

	offset -= base;
	offset = ~offset;

	if(!length) {
		length = 1;

		do {
			length <<= 1;
			length += getbit();
		} while(!getbit());
	}

	result.offset = offset;
	result.length = ++length;

	return result;
}

static unsigned wraps(unsigned cursor, unsigned length, unsigned limit) {
	return ((cursor + length) ^ cursor) >=	 limit;
}

int
#ifdef _MSC_VER
__cdecl
#endif
main(int argc, char *argv[]) {
	enum { INFINITE_WINDOW = (~0U >> 1) + 1 };

	unsigned window;
	signed origin;
	const char *input_name;
	const char *output_name;
	const char *program_name;
	const char *output_ext;
	unsigned is_cbm;

	unsigned limit;
	unsigned char *data;
	unsigned cursor;

	// parse command line
	window = INFINITE_WINDOW;
	origin = 0;
	program_name = *argv;

	while(++argv, --argc >= 2) {
		if(!strcmp(*argv, "-w")) {
			window = strtoul(*++argv, NULL, 0);
			--argc;
		} else if(!strcmp(*argv, "-l")) {
			origin = strtoul(*++argv, NULL, 0);
			--argc;
		} else {
			break;
		}
	}
	
	if(argc != 2) {
		fprintf (
			stderr,
			"syntax: %s [-w window-size] [-l load-address] {input.lz} {output.bin|prg}\n",
			program_name
		);
		return EXIT_FAILURE;
	}
	
	input_name = *argv++;
	output_name = *argv++;
	output_ext = strrchr(output_name, '.');
	is_cbm = output_ext && !strcmp(output_ext, ".prg");

	// decompress file
	if(!freopen(input_name, "rb", stdin)) {
		fprintf(stderr, "error: cannot open '%s'\n", input_name);
		return EXIT_FAILURE;
	}

	data = NULL;
	limit = RUN_LIMIT << 4;
	cursor = origin;

	for(;;) {
		unsigned safe_limit = limit - RUN_LIMIT;

		if(data = realloc(data, limit), !data) {
			fprintf(stderr, "error: cannot allocate %u byte buffer",
				limit);
			return EXIT_FAILURE;
		}
		
		data -= origin;

		do {
			unsigned length;
			unsigned offset;
			struct match match;

			if(getbit()) {
				unsigned last_cursor;

				length = decode_literals();

#				if SHOW_STATS
				literal_bytes += length;
				++literal_runs;
#				endif

#				if SHOW_TRACE
				printf (
					"literal($%04x, %u)\n",
					cursor,
					length
				);
#				endif

				if(wraps(cursor, length - 1, window)) {
					fprintf(stderr, "warning: literal run "
						"crosses the sliding-window boundary\n");
				}

				offset = length;

				do {
					data[cursor + --offset] = getbyte();
				} while(offset);

				last_cursor = cursor;
				cursor += length;

				if(wraps(last_cursor, length, RUN_LIMIT)) {
					// implicit matches runs can't cross page boundaries
					continue;
				}
			}

			match = decode_match();
			offset = match.offset;
			length = match.length;

			if(length > RUN_LIMIT) {
				goto end_of_file;
			}

#			if SHOW_TRACE
			printf (
				"match  ($%04x, $%04x => $%04x, %u)\n",
				cursor,
				(unsigned short) -(signed) offset,
				cursor - offset,
				length
			);
#			endif

#			if SHOW_STATS
			match_bytes += length;
			++match_count;
#			endif

			if(wraps(cursor, length - 1, window)) {
				fprintf(stderr, "warning: match writes past "
					"sliding-window boundary\n");
			}
			
			if(wraps(cursor - offset, length - 1, window)) {
				fprintf(stderr, "warning: match reads past "
					"sliding-window boundary\n");
			}

			do {
				data[cursor] = data[cursor - offset];
			} while(++cursor, --length);
		} while(cursor < safe_limit);

		limit <<= 1;
		data += origin;
	}

end_of_file:

#	if SHOW_STATS
	{
		printf (
			"short offsets: (%3u, %3u, %3u, %3u)\n"
			"long offsets:  (%3u, %3u, %3u, %3u)\n"
			"%4u matches,  %5u bytes, %f avg\n"
			"%4u literals, %5u bytes, %f avg\n"
			"%4u offsets,  %5u bits,  %f avg\n",

			short_freq[0],
			short_freq[1],
			short_freq[2],
			short_freq[3],
			long_freq[0],
			long_freq[1],
			long_freq[2],
			long_freq[3],

			match_count,
			match_bytes,
			(double) match_bytes / match_count,

			literal_runs,
			literal_bytes,
			(double) literal_bytes / literal_runs,

			match_count,
			offset_bits,
			(double) offset_bits / match_count
		);
	}
#	endif

	if(!freopen(output_name, "wb", stdout)) {
		fprintf(stderr, "error: cannot create '%s'\n", output_name);
		return EXIT_FAILURE;
	}

	if(is_cbm) {
		putchar(origin);
		putchar(origin >> 8);
	}

	data += origin;
	cursor -= origin;

	fwrite(data, cursor, 1, stdout);
	return EXIT_SUCCESS;
}