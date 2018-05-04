		;Basic line: 1 SYS2061
		*= $0801
		.byte $0b,$08,$39,$05,$9e,$32
		.byte $30,$36,$31,$00,$00,$00


;-------------------------------------------------------------------------------
;Decrunch and start the real program
;-------------------------------------------------------------------------------
start		ldx #<target		;Set the target buffer address
		stx lz_dst+0
		ldx #>target
		stx lz_dst+1

		ldx #>source		;Select the source address
		stx lz_sector_ptr1+1
		stx lz_sector_ptr2+1
		stx lz_sector_ptr3+1
		ldx #<source

		jsr lz_decrunch		;Now decrunch it

		jmp target		;And run the unpacked data


;-------------------------------------------------------------------------------
;Decruncher code and data
;-------------------------------------------------------------------------------
		;Zero-page assignments
lz_dst		= $fb
lz_bits		= $fd
lz_scratch	= $fe
		;Dummy sector buffer address. Anything page-aligned will do
lz_sector	= $0400

		;Callback for "fetching" another sector of data. In this case
		;we merely increment the source pointer
lz_fetch_sector	inc lz_sector_ptr1+1
		inc lz_sector_ptr2+1
		inc lz_sector_ptr3+1
		rts

		;Bake the decruncher itself in
		.include "../decrunch.asm"


;-------------------------------------------------------------------------------
;Here goes the actual content..
;-------------------------------------------------------------------------------
		;Include the packed data
source		.binary "self_extractee.lz"
		;Target address to decompress to
target		= $4000
