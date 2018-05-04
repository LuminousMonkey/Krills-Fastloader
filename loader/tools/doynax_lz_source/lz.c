#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <assert.h>
#include <ctype.h>

#ifdef _MSC_VER
#	include <malloc.h>
#	include <io.h>
#	define alloca _alloca
#	define inline __forceinline
#	pragma comment(linker, "/OPT:NOWIN98")
#else
#	include <sys/stat.h>
#	if defined(__GNUC__)
#		include <alloca.h>
#		define inline __attribute__((always_inline)) 
#	endif
#endif

typedef enum {
	false,
	true
} bool;

enum {
	RUN_LIMIT = 0x100,

	VERIFY_COST_MODEL = false,

	SHORT_BITS_A = 3,
	SHORT_BITS_B = 6,
	SHORT_BITS_C = 8,
	SHORT_BITS_D = 10,

	LONG_BITS_A = 4,
	LONG_BITS_B = 6,
	LONG_BITS_C = 9,
	LONG_BITS_D = 12
};

enum {
	SHORT_BASE_A = 1,
	SHORT_BASE_B = (1 << SHORT_BITS_A) + SHORT_BASE_A,
	SHORT_BASE_C = (1 << SHORT_BITS_B) + SHORT_BASE_B,
	SHORT_BASE_D = (1 << SHORT_BITS_C) + SHORT_BASE_C,

	LONG_BASE_A = 1,
	LONG_BASE_B = (1 << LONG_BITS_A) + LONG_BASE_A,
	LONG_BASE_C = (1 << LONG_BITS_B) + LONG_BASE_B,
	LONG_BASE_D = (1 << LONG_BITS_C) + LONG_BASE_C,

	////////

	SHORT_LIMIT_A = (1 << SHORT_BITS_A),
	SHORT_LIMIT_B = (1 << SHORT_BITS_B) + SHORT_LIMIT_A,
	SHORT_LIMIT_C = (1 << SHORT_BITS_C) + SHORT_LIMIT_B,
	SHORT_LIMIT_D = (1 << SHORT_BITS_D) + SHORT_LIMIT_C,

	LONG_LIMIT_A = (1 << LONG_BITS_A),
	LONG_LIMIT_B = (1 << LONG_BITS_B) + LONG_LIMIT_A,
	LONG_LIMIT_C = (1 << LONG_BITS_C) + LONG_LIMIT_B,
	LONG_LIMIT_D = (1 << LONG_BITS_D) + LONG_LIMIT_C
};

typedef struct {
	unsigned short match_length;
	unsigned short match_offset;

	signed chosen_length;

	union {
		signed hash_link;
		unsigned cumulative_cost;
	};
} lz_info;

typedef struct {
	unsigned char *src_data;
	unsigned src_begin;
	unsigned src_end;

	FILE *dst_file;
	unsigned dst_bits;
	unsigned dst_used;

	lz_info *info;

	signed hash_table[0x100];
	unsigned char dst_literals[RUN_LIMIT * 2];
} lz_context;


//////// various utility functions and bithacks ////////

#define countof(n) (sizeof(n) / sizeof *(n))

inline unsigned _log2(unsigned value) {
#	ifdef __GNUC__
	enum { WORD_BITS = sizeof(unsigned) * CHAR_BIT };

	return (WORD_BITS - 1) ^ __builtin_clz(value);
#	else
	signed bits = -1;

	do {
		++bits;
	} while(value >>= 1);
	
	return bits;
#	endif
}

inline bool wraps(unsigned cursor, unsigned length, unsigned limit) {
	return ((cursor + length) ^ cursor) >=	limit;
}

inline unsigned remainder(signed cursor, signed window) {
	return -(cursor | -window);
}

#ifdef min
#	undef min
#endif

inline unsigned min(unsigned a, unsigned b) {
	return (a < b) ? a : b;
}


//////// manage the output stream ////////

inline void _output_doflush(lz_context *ctx) {
	fputc(ctx->dst_bits, ctx->dst_file);
	fwrite(ctx->dst_literals, ctx->dst_used, 1, ctx->dst_file);

	ctx->dst_bits = 1;
	ctx->dst_used = 0;
}

inline void output_create(lz_context *ctx, const char *name) {
	if(ctx->dst_file = fopen(name, "wb"), !ctx->dst_file) {
		fprintf(stderr, "error: cannot create '%s'\n", name);
		exit(EXIT_FAILURE);
	}

	ctx->dst_bits = 1;
	ctx->dst_used = 0;
}

inline void output_close(lz_context *ctx) {
	if(ctx->dst_bits != 1) {
		while(ctx->dst_bits < 0x100) {
			ctx->dst_bits <<= 1;
		}

		fputc(ctx->dst_bits, ctx->dst_file);
	}

	fwrite(ctx->dst_literals, ctx->dst_used, 1, ctx->dst_file);
	fclose(ctx->dst_file);
}

inline void output_bit(lz_context *ctx, unsigned bit) {
	if(ctx->dst_bits >= 0x100) {
		_output_doflush(ctx);
	}

	ctx->dst_bits <<= 1;
	ctx->dst_bits += bit & 1;
}

inline void output_literal(lz_context *ctx, unsigned value) {
	ctx->dst_literals[ctx->dst_used++] = value;
}

inline unsigned output_bitsize(lz_context *ctx) {
	unsigned total;
	unsigned bitbuffer;
	
	total = ftell(ctx->dst_file);
	total += ctx->dst_used;
	total <<= 3;

	for(bitbuffer = ctx->dst_bits; bitbuffer > 1; bitbuffer >>= 1) {
		++total;
	}

	return total;
}


//////// read file into memory and allocate per-byte buffers ////////

void read_input(lz_context *ctx, const char *name, bool is_cbm) {
	FILE *file;
	signed length;
	unsigned origin;

	if(file = fopen(name, "rb"), !file) {
		fprintf(stderr, "error: unable to open '%s'\n", name);
		exit(EXIT_FAILURE);
	}

#	ifdef _MSC_VER
	length = _filelength(_fileno(file));
#	else
	{
		struct stat stat;
		stat.st_size = 0;
		fstat(fileno(file), &stat);
		length = stat.st_size;
	}
#	endif

	if(length <= 0) {
		fprintf(stderr, "error: cannot determine length of '%s'\n",
			name);
		exit(EXIT_FAILURE);
	}

	{
		unsigned count;

		// give us a sentinel for the info structure and prevent two-byte
		// hashing from overrunning the buffer
		count = length + 1;

		ctx->info = malloc(count *
			(sizeof *ctx->info + sizeof *ctx->src_data));
		ctx->src_data = (void *) &ctx->info[count];

		if(!ctx->info) {
			fprintf(stderr, "error: cannot allocate memory buffer\n");
			exit(EXIT_FAILURE);
		}

		if(fread(ctx->src_data, length, 1, file) != 1) {
			fprintf(stderr, "error: cannot read '%s'\n", name);
			exit(EXIT_FAILURE);
		}
	}

	// deal with the PRG file header. we don't write the loading
	// address back out to compressed file, however we *do* need to
	// consider the decompression address when deciding whether a
	// run crosses a page boundary
	origin = 0;

	if(is_cbm) {
		length -= 2;

		if(length < 0) {
			fprintf(stderr, "error: CBM .prg file is too short to "
				"fit a 2-byte load address\n");
			exit(EXIT_FAILURE);
		}

		origin = *ctx->src_data++;
		origin += *ctx->src_data++ << 8;
	}

	ctx->info -= origin;
	ctx->src_data -= origin;
	ctx->src_begin = origin;
	ctx->src_end = origin + length;
}


//////// determine the longest match for every position of the file ////////

inline signed *hashof(lz_context *ctx, unsigned a, unsigned b) {
	static const unsigned char random[] = {
		0x17, 0x80, 0x95, 0x4f, 0xc7, 0xd1, 0x15, 0x13,
		0x91, 0x57, 0x0f, 0x47, 0xd0, 0x59, 0xab, 0xf0,
		0xa7, 0xf5, 0x36, 0xc0, 0x24, 0x9c, 0xed, 0xfd,
		0xd4, 0xf3, 0x51, 0xb4, 0x8c, 0x97, 0xa3, 0x58,
		0xcb, 0x61, 0x78, 0xb1, 0x3e, 0x7e, 0xfb, 0x41,
		0x39, 0xa6, 0x8e, 0x10, 0xa1, 0xba, 0x62, 0xcd,
		0x94, 0x02, 0x0d, 0x2b, 0xdb, 0xd7, 0x44, 0x16,
		0x29, 0x4d, 0x68, 0x0a, 0x6b, 0x6c, 0xa2, 0xf8,
		0xc8, 0x9f, 0x25, 0xca, 0xbd, 0x4a, 0xc2, 0x35,
		0x53, 0x1c, 0x40, 0x04, 0x76, 0x43, 0xa9, 0xbc,
		0x46, 0xeb, 0x99, 0xe9, 0xf6, 0x5e, 0x8f, 0x8a,
		0xf1, 0x5d, 0x21, 0x33, 0x0b, 0x82, 0xdf, 0x52,
		0xea, 0x27, 0x22, 0x9a, 0x6f, 0xad, 0xe5, 0x83,
		0x11, 0xbe, 0xa4, 0x85, 0x1d, 0xb3, 0x77, 0xf4,
		0xef, 0xb7, 0xf2, 0x03, 0x64, 0x6d, 0x1b, 0xee,
		0x72, 0x08, 0x66, 0xc6, 0xc1, 0x06, 0x56, 0x81,
		0x55, 0x60, 0x70, 0x8d, 0x23, 0xb2, 0x65, 0x5b,
		0xff, 0x4c, 0xb9, 0x7a, 0xd6, 0xe6, 0x19, 0x9b,
		0xb5, 0x49, 0x7d, 0xd8, 0x45, 0x1a, 0x84, 0x32,
		0xdd, 0xbf, 0x9e, 0x2f, 0xd2, 0xec, 0x92, 0x0e,
		0xe8, 0x7c, 0x7f, 0x00, 0x86, 0xde, 0xb6, 0xcf,
		0x05, 0x69, 0xd5, 0x37, 0xe4, 0x30, 0x3c, 0xe1,
		0x4b, 0xaa, 0x3b, 0x2d, 0xda, 0x5c, 0xcc, 0x67,
		0x20, 0xb0, 0x6a, 0x1f, 0xf9, 0x01, 0xac, 0x2e,
		0x71, 0xf7, 0xfc, 0x3f, 0x42, 0xd3, 0xbb, 0xa8,
		0x38, 0xce, 0x12, 0x96, 0xe2, 0x14, 0x87, 0x4e,
		0x63, 0x07, 0xae, 0xdc, 0xa5, 0xc9, 0x0c, 0x90,
		0xe7, 0xd9, 0x09, 0x2a, 0xc4, 0x3d, 0x5a, 0x34,
		0x8b, 0x88, 0x98, 0x48, 0xfa, 0xc3, 0x26, 0x75,
		0xfe, 0xa0, 0x7b, 0x50, 0x2c, 0x89, 0x18, 0x9d,
		0x3a, 0x73, 0x6e, 0x5f, 0xc5, 0xaf, 0xb8, 0x74,
		0x93, 0xe3, 0x79, 0x28, 0xe0, 0x1e, 0x54, 0x31
	};

	unsigned bucket = random[a] ^ b;

	return &ctx->hash_table[bucket];
}

inline void record_matches(lz_context *ctx, unsigned window) {
	unsigned i;
	unsigned cursor;
	unsigned offset_limit;

	const unsigned src_end = ctx->src_end;
	const unsigned char *src_data = ctx->src_data;
	lz_info *info = ctx->info;

	for(i = 0; i < countof(ctx->hash_table); ++i) {
		ctx->hash_table[i] = INT_MIN;
	}

	offset_limit = min(window, LONG_LIMIT_D);
	cursor = ctx->src_begin;

	do {
		unsigned match_length;
		unsigned match_offset;
		signed cursor_limit;
		unsigned length_limit;
		signed *hash_bucket;
		signed hash_link;

		cursor_limit = cursor - offset_limit;

		length_limit = RUN_LIMIT;
		length_limit = min(length_limit, remainder(cursor, window));
		length_limit = min(length_limit, src_end - cursor);

		hash_bucket = hashof (
			ctx,
			src_data[cursor + 0],
			src_data[cursor + 1]
		);

		hash_link = *hash_bucket;

		match_length = 0;

		while(hash_link >= 0) {
			unsigned length = 0;

			if(hash_link < cursor_limit) {
				break;
			}

			while (
				src_data[cursor + length] ==
				src_data[hash_link + length]
			) {
				if(++length >= length_limit) {
					break;
				}
			}

			if(length > match_length) {
				match_length = length;
				match_offset = hash_link;
			}

			hash_link = info[hash_link].hash_link;
		}

		info[cursor].hash_link = *hash_bucket;
		*hash_bucket = cursor;

		// clip matches where the source crosses the window boundary
		match_length = min(match_length, remainder(match_offset, window));

		// reject matches which cannot be represented
		match_offset = cursor - match_offset;

		if (
			match_length < 2 ||
			match_length == 2 && match_offset > SHORT_LIMIT_D
		) {
			match_length = 1;
		}

		info[cursor].match_length = match_length;
		info[cursor].match_offset = match_offset;

	} while(++cursor < src_end);
}


//////// try to figure out what matches would be the most beneficial ////////

inline unsigned costof_run(unsigned run) {
	return _log2(run) * 2 + 1;
}

inline unsigned costof_literals(unsigned address, unsigned length) {
	unsigned cost;

	cost = length * 8;
	cost += costof_run(length);
	cost += wraps(address, length, RUN_LIMIT);

	return cost;
}

inline unsigned costof_short_match(unsigned offset, unsigned length) {
	unsigned cost = 3;

	if(offset <= SHORT_LIMIT_A) {
		cost += SHORT_BITS_A;
	} else if(offset <= SHORT_LIMIT_B) {
		cost += SHORT_BITS_B;
	} else if(offset <= SHORT_LIMIT_C) {
		cost += SHORT_BITS_C;
	} else {
		cost += SHORT_BITS_D;
	}

	return cost + costof_run(length - 1);
}

inline unsigned costof_long_match(unsigned offset, unsigned length) {
	unsigned cost = 3;

	if(offset <= LONG_LIMIT_A) {
		cost += LONG_BITS_A;
	} else if(offset <= LONG_LIMIT_B) {
		cost += LONG_BITS_B;
	} else if(offset <= LONG_LIMIT_C) {
		cost += LONG_BITS_C;
	} else {
		cost += LONG_BITS_D;
	}

	return cost + costof_run(length - 1);
}

inline void optimal_parsing(lz_context *ctx) {
	signed cursor;

	signed src_begin = ctx->src_begin;
	lz_info *info = ctx->info;

	cursor = ctx->src_end;

	info[cursor].cumulative_cost = 0;
	info[cursor].chosen_length = 0;

	--cursor;

	do {
		unsigned minimum_cost;
		signed minimum_length;
		unsigned length_limit;

		minimum_length = -info[cursor + 1].chosen_length;

		if(minimum_length > 0 && minimum_length <= RUN_LIMIT) {
			++minimum_length;
			minimum_cost =
				info[cursor + minimum_length].cumulative_cost;
		} else {
			minimum_cost = info[cursor + 1].cumulative_cost;
			minimum_length = 1;
		}

		minimum_cost += costof_literals(cursor, minimum_length);
		minimum_length = -minimum_length;

		length_limit = info[cursor].match_length;

		if(length_limit >= 2) {
			unsigned cost;
			unsigned length;
			unsigned offset;

			length = 2;
			offset = info[cursor].match_offset;

			cost = costof_short_match(offset, length);

			if(offset <= SHORT_LIMIT_D) {
				goto accept_short;
			}

			while(++length <= length_limit) {
				offset = info[cursor].match_offset;
				cost = costof_long_match(offset, length);

accept_short:

				cost += info[cursor + length].cumulative_cost;

				if(cost < minimum_cost) {
					minimum_cost = cost;
					minimum_length = length;
				}
			}
		}

		info[cursor].cumulative_cost = minimum_cost;
		info[cursor].chosen_length = minimum_length;
	} while(--cursor >= src_begin);
}


//////// write the generated matches and literal runs ////////

inline void encode_literals (
	lz_context *ctx,
	unsigned cursor,
	unsigned length
) {
	signed bit;
	const unsigned char *data;

	bit = _log2(length);

	while(--bit >= 0) {
		output_bit(ctx, 0);
		output_bit(ctx, length >> bit);
	}

	output_bit(ctx, 1);

	data = &ctx->src_data[cursor];

	do {
		output_literal(ctx, data[--length]);
	} while(length);
}

inline void encode_match (
	lz_context *ctx,
	signed offset,
	unsigned length
) {
	unsigned offset_bits;
	unsigned offset_base;
	signed length_bit;

	// write initial length bit
	length_bit = _log2(--length);
	output_bit(ctx, --length_bit < 0);

	// write offset prefix
	if(length == 2 - 1) {
		if(offset <= SHORT_LIMIT_A) {
			offset_bits = SHORT_BITS_A;
			offset_base = SHORT_BASE_A;

			output_bit(ctx, 0);
			output_bit(ctx, 0);
		} else if(offset <= SHORT_LIMIT_B) {
			offset_bits = SHORT_BITS_B;
			offset_base = SHORT_BASE_B;

			output_bit(ctx, 0);
			output_bit(ctx, 1);
		} else if(offset <= SHORT_LIMIT_C) {
			offset_bits = SHORT_BITS_C;
			offset_base = SHORT_BASE_C;

			output_bit(ctx, 1);
			output_bit(ctx, 0);
		} else {
			offset_bits = SHORT_BITS_D;
			offset_base = SHORT_BASE_D;

			output_bit(ctx, 1);
			output_bit(ctx, 1);
		}
	} else {
		if(offset <= LONG_LIMIT_A) {
			offset_bits = LONG_BITS_A;
			offset_base = LONG_BASE_A;

			output_bit(ctx, 0);
			output_bit(ctx, 0);
		} else if(offset <= LONG_LIMIT_B) {
			offset_bits = LONG_BITS_B;
			offset_base = LONG_BASE_B;

			output_bit(ctx, 0);
			output_bit(ctx, 1);
		} else if(offset <= LONG_LIMIT_C) {
			offset_bits = LONG_BITS_C;
			offset_base = LONG_BASE_C;

			output_bit(ctx, 1);
			output_bit(ctx, 0);
		} else {
			offset_bits = LONG_BITS_D;
			offset_base = LONG_BASE_D;

			output_bit(ctx, 1);
			output_bit(ctx, 1);
		}
	}

	// write offset payload
	offset -= offset_base;
	offset = ~offset;

	while(offset_bits & 7) {
		output_bit(ctx, offset >> --offset_bits);
	}

	if(offset_bits) {
		output_literal(ctx, offset);
	}

	// write any remaining length bits
	while(length_bit >= 0) {
		output_bit(ctx, length >> length_bit);
		output_bit(ctx, --length_bit < 0);
	}
}

inline void write_output(lz_context *ctx, const char *name) {
	unsigned cursor;
	bool implicit_match;

	unsigned src_end = ctx->src_end;
	const char *src_data = ctx->src_data;
	lz_info *info = ctx->info;

	output_create(ctx, name);

	cursor = ctx->src_begin;
	implicit_match = false;

	do {
		signed length = info[cursor].chosen_length;

		if(length > 0) {
			if(!implicit_match) {
				output_bit(ctx, 0);
			}

			encode_match(ctx, info[cursor].match_offset, length);

			implicit_match = false;
		} else {
			length = -length;

			output_bit(ctx, 1);
			encode_literals(ctx, cursor, length);

			implicit_match = !wraps(cursor, length, RUN_LIMIT);
		}

		cursor += length;
	} while(cursor < src_end);

	if(VERIFY_COST_MODEL) {
		unsigned expected = info->cumulative_cost;
		unsigned actual = output_bitsize(ctx);

		if(expected != actual) {
			printf (
				"expected: %u\n"
				"actual:   %u\n",
				expected,
				actual
			);
		}
	}

	// the sentinel is a maximum-length match
	if(!implicit_match) {
		output_bit(ctx, 0);
	}

	encode_match(ctx, 1, RUN_LIMIT + 1);
	output_close(ctx);
}


//////// the main function ////////

int
#ifdef _MSC_VER
__cdecl
#endif
main(int argc, char *argv[]) {
	enum { INFINITE_WINDOW = (unsigned) INT_MIN };

	const char *program_name;
	const char *input_name;
	char *output_name;
	unsigned name_length;
	bool is_cbm;
	unsigned window;
	unsigned i;
	
	lz_context ctx;

	// parse command line
	program_name = *argv;
	output_name = NULL;
	window = INFINITE_WINDOW;

	while(++argv, --argc >= 2) {
		if(!strcmp(*argv, "-w")) {
			window = strtoul(*++argv, NULL, 0);
			--argc;

			if(window < RUN_LIMIT || ((window - 1) & window)) {
				fprintf(stderr, "error: window size must be a power of two "
					"larger than 0x%x\n", RUN_LIMIT);
				return EXIT_FAILURE;
			}
		} else if(!strcmp(*argv, "-o")) {
			output_name = *++argv;
			--argc;
		} else {
			break;
		}
	}
	
	if(argc != 1) {
		fprintf (
			stderr,
			"syntax: %s [-w window-size] [-o output.lz] {input.prg|bin}\n",
			program_name
		);
		return EXIT_FAILURE;
	}
	
	input_name = *argv;

	// check extension to figure out whether it's a .PRG file
	name_length = 0;

	for(i = 0; input_name[i]; ++i) {
		if(input_name[i] == '.') {
			name_length = i;
		}
	}

	is_cbm = false;

	if(!name_length) {
		name_length = i;
	} else if(!strcmp(&input_name[name_length], ".prg")) {
		is_cbm = true;

		if(window != INFINITE_WINDOW) {
			fprintf (
				stderr,
				"warning: sliding-window used with a PRG file\n"
			);
		}
	}

	// if necessary generate output file by substituting the
	// extension for .lz
	if(!output_name) {
		static const char extension[] = ".lz";

		output_name = alloca(name_length + sizeof extension);

		memcpy(output_name, input_name, name_length);
		memcpy(&output_name[name_length], extension, sizeof extension);
	}

	// do the compression
	read_input(&ctx, input_name, is_cbm);
	record_matches(&ctx, window);
	optimal_parsing(&ctx);
	write_output(&ctx, output_name);

	return EXIT_SUCCESS;
}