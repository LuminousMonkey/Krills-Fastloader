#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_LENGTHS "3/6/8/10:4/7/10/13"

enum { RUN_LIMIT = 0x100 };

typedef struct  {
	unsigned bits;
	unsigned base;
} offset_length_t;

static offset_length_t short_offset[4];
static offset_length_t long_offset[4];

static signed char shift = 0x80U;

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
		// The short prefixes are inverted relative to the long ones
		prefix ^= 3;
		bits = short_offset[prefix].bits;
		base = short_offset[prefix].base;
	} else {
		bits = long_offset[prefix].bits;
		base = long_offset[prefix].base;
	}

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

// Parse out the set of offset bit lengths from a descriptor string
static void prepare_offset_lengths(offset_length_t *table, size_t count) {
	unsigned base = 1;
	do {
		table->base = base;
		base += 1 << table->bits;
	} while(++table, --count);
}

static unsigned parse_offset_lengths(const char *text) {
	if(sscanf(text, "%u/%u/%u/%u:%u/%u/%u/%u",
		&short_offset[0].bits, &short_offset[1].bits,
		&short_offset[2].bits, &short_offset[3].bits,
		&long_offset[0].bits, &long_offset[1].bits,
		&long_offset[2].bits, &long_offset[3].bits) != 8) {
		return 0;
	}
	prepare_offset_lengths(short_offset, 4);
	prepare_offset_lengths(long_offset, 4);
	return 1;
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
	char *output_name = NULL;
	const char *program_name;
	unsigned per_page = 0;
	unsigned show_trace = 0;

	unsigned limit;
	unsigned char *data;
	unsigned cursor;

	// Parse the command line
	window = INFINITE_WINDOW;
	origin = 0;
	program_name = *argv;
	parse_offset_lengths(DEFAULT_LENGTHS);

	while(++argv, --argc) {
		if(argc >= 2 && !strcmp(*argv, "-o")) {
			output_name = *++argv;
			--argc;
		} else if(argc >= 2 && !strcmp(*argv, "--window")) {
			window = strtoul(*++argv, NULL, 0);
			--argc;
			per_page = 1;
		} else if(argc >= 2 && !strcmp(*argv, "--load")) {
			origin = strtoul(*++argv, NULL, 0);
			--argc;
		} else if(!strcmp(*argv, "--per-page")) {
			per_page = 1;
		} else if (argc >= 2 && !strcmp(*argv, "--offset-lengths")) {
			if(!parse_offset_lengths(*++argv))
				break;
			--argc;
		} else if(!strcmp(*argv, "--trace-coding")) {
			show_trace = 1;
		} else {
			break;
		}
	}

	if(argc != 1) {
		fprintf (
			stderr,
			"syntax: %s\n"
			"\t[-o {output.bin|prg}]\n"
			"\t[--window window-size]\n"
			"\t[--load load-address]\n"
			"\t[--per-page]\n"
			"\t[--offset-lengths s1/s2/s3/s4:l1/l2/l3/l4]\n"
			"\t[--trace-coding]\n"
			"\t{input.lz}\n",
			program_name
		);
		return EXIT_FAILURE;
	}

	input_name = *argv++;

	// Decompress file
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

			const char *explicit = "explicit-";

			if(getbit()) {
				unsigned last_cursor;

				length = decode_literals();

				if(show_trace) {
					printf (
						"$%04x literal(%u bytes)\n",
						cursor,
						length
					);
				}

				if(wraps(cursor, length - 1, window)) {
					fprintf(stderr, "warning: literal run "
						"crosses the sliding-window boundary\n");
				}

				offset = length;

				do
					data[cursor + --offset] = getbyte();
				while(offset);

				last_cursor = cursor;
				cursor += length;

				if(per_page) {
					// Implicit match runs can't cross page boundaries when
					// doing per-page rendering
					if(wraps(last_cursor, length, RUN_LIMIT))
						continue;
				} else {
					// After a maximum length run the subsequent token may
					// either be another literal or a match
					if(length == RUN_LIMIT)
						continue;
				}

				explicit = "";
			}

			match = decode_match();
			offset = match.offset;
			length = match.length;

			if(length > RUN_LIMIT)
				goto end_of_file;

			if(show_trace) {
				printf (
					"$%04x %smatch(-%u/$%04x, %u bytes)\n",
					cursor,
					explicit,
					offset,
					cursor - offset,
					length
				);
			}

			if(wraps(cursor, length - 1, window)) {
				fprintf(stderr, "warning: match writes past "
					"sliding-window boundary\n");
			}

			if(wraps(cursor - offset, length - 1, window)) {
				fprintf(stderr, "warning: match reads past "
					"sliding-window boundary\n");
			}

			do
				data[cursor] = data[cursor - offset];
			while(++cursor, --length);
		} while(cursor < safe_limit);

		limit <<= 1;
		data += origin;
	}

end_of_file:

	// Write the decompressed output if a file has been specified
	if(output_name) {
		const char *output_ext;

		if(!freopen(output_name, "wb", stdout)) {
			fprintf(stderr, "error: cannot create '%s'\n", output_name);
			return EXIT_FAILURE;
		}

		// Include an address header if the output is a PRG file
		output_ext = strrchr(output_name, '.');
		if(output_ext && !strcmp(output_ext, ".prg")) {
			putchar(origin);
			putchar(origin >> 8);
		}

		data += origin;
		cursor -= origin;
		fwrite(data, cursor, 1, stdout);
	}

	return EXIT_SUCCESS;
}