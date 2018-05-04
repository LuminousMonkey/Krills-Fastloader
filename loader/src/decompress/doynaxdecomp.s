
.macro SETDECOMPGETBYTE
                sta toloadbt + $01
                sty toloadbt + $02
.endmacro

lz_dst          = decdestlo             ;; destination pointer. initialize
lz_dst_lo       = lz_dst + $00          ;; this to whatever address you want
lz_dst_hi       = lz_dst + $01          ;; to decompress to
                                        ;;
lz_bits         = DECOMPVARS + $00      ;; shift register. initialized to $80
                                        ;;
lz_scratch      = DECOMPVARS + $01      ;; temporary zeropage storage. doesn't
                                        ;; need to be preserved between calls
                                        ;;
lz_sector       = $0400                 ;; the one-page buffer from which the
                                        ;; compressed data is actually read,
                                        ;; and which is refilled by
                                        ;; lz_fetch_sector

.ifndef DYNLINK_EXPORT
	.if GETC_API
                .assert .lobyte(getcmem) <> .lobyte(getcmemfin), error, "Error: Invalid code optimization"
                .assert .lobyte(getcmem) <> .lobyte(getcmemeof), error, "Error: Invalid code optimization"
	.endif; GETC_API
	.if BYTESTREAM
		.if LOAD_VIA_KERNAL_FALLBACK
                .assert .lobyte(getcmem) <> .lobyte(getckernal), error, "Error: Invalid code optimization"
		.endif; LOAD_VIA_KERNAL_FALLBACK
                .assert .lobyte(getcmem) <> .lobyte(getcload),   error, "Error: Invalid code optimization"
	.endif; BYTESTREAM
.endif; !DYNLINK_EXPORT

decompress:     CHUNKENTRY
				jsr toloadbt
                sta lz_dst_lo; destination lo-byte cannot be overridden
                jsr toloadbt
storedadrh:     sta lz_dst_hi
                CHUNKSETUP
                jsr lz_fetch_sector
                dex
				lda #$80
                sta lz_bits
				SKIPWORD
decomppage:     inc lz_dst_hi
				CHUNKCHECK
				jsr lz_decrunch
.if BYTESTREAM
				php
                jsr maybegetblock
				plp
.endif; BYTESTREAM
                bcs decomppage

				; housekeeping to finish decompression
.if BYTESTREAM
	.if LOAD_VIA_KERNAL_FALLBACK
				lda toloadbt + $01
                cmp #.lobyte(getckernal)
                beq decompfinished
	.endif; LOAD_VIA_KERNAL_FALLBACK
                stx YPNTRBUF
.endif; BYTESTREAM
                stx getcmemadr + $01
                dec getcmemadr + $02
                ; move pointer beyond last data byte
				jsr toloadbt
.if GETC_API
                lda getcmemadr + $01
                sta getcmemfin + $01
                lda getcmemadr + $02
				sta getcmemfin + $02
.endif; GETC_API

				; decompression finished
decompfinished:	CHUNKEOF
				rts

toloadbt:       jmp getcmem

.if BYTESTREAM
maybegetblock:  lda toloadbt + $01
                eor #.lobyte(getcload)
                beq dogetblock
				rts
dogetblock:
	.if LOAD_UNDER_D000_DFFF & (PLATFORM <> diskio::platform::COMMODORE_16)
				ENABLE_IO_SPACE_Y
	.endif; LOAD_UNDER_D000_DFFF & (PLATFORM <> diskio::platform::COMMODORE_16)
                BRANCH_IF_BLOCK_NOT_READY :++
                jsr getnewblk
                lda toloadbt + $01
                cmp #.lobyte(getcmem)
                bne :+
                jsr getcmem
:				rts
:				clc
				jmp loadbytret
.endif; BYTESTREAM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; this is the user's hook to replentish the sector buffer with some new
;; bytes.
;; a and y are expected to be preserved. on exit carry must be set and x
;; should point to the first byte of the new data, e.g. zero for a full
;; 256-byte page of data or two to skip past the sector and track links
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

lz_fetch_sector:pha
                sty save_y+1

                ;; now do whatever it is you have to do to load the next
                ;; sector..
.if BYTESTREAM
                lda toloadbt + $01
                cmp #.lobyte(getcload)
                beq isloading
	.if LOAD_VIA_KERNAL_FALLBACK
                cmp #.lobyte(getcmem)
                beq getblkfrommem
				jsr getckernal
				sta onebytebuffer
				lda #.lobyte(onebytebuffer - $ff)
				ldy #.hibyte(onebytebuffer - $ff)
				ldx #$ff
				bne setblockpntrs
onebytebuffer:  .byte $00
	.endif; LOAD_VIA_KERNAL_FALLBACK
.endif; BYTESTREAM

getblkfrommem:  ldx getcmemadr + $01
                lda #$00
                sta getcmemadr + $01
                ldy getcmemadr + $02
                inc getcmemadr + $02

.if BYTESTREAM
                bne setblockpntrs; jmp

isloading:      jsr maybegetblock
                ldx YPNTRBUF
                inx
                bne :+; branch if first block
                jsr toloadbt
                ldx YPNTRBUF
                SKIPBYTE
:               dex
                lda #$ff
                sta YPNTRBUF
updateblkpntrs: lda getdbyte + $01
                ldy getdbyte + $02
.endif; BYTESTREAM
setblockpntrs:  sta lz_sector0 + $00
                sta lz_sector1 + $00
                sta lz_sector2 + $00
                sty lz_sector0 + $01
                sty lz_sector1 + $01
                sty lz_sector2 + $01

save_y:         ldy #$00
                pla
                sec
                rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; streaming lempel-ziv decompressor.
;;
;; the decoder renders one page of output per call, and potentially even
;; writes parts of the subsequent page. it's entirely up to the caller to
;; advance the lz_dst_hi (or not). carry will be cleared on exit when we've
;; reached to end of the file.
;;
;; on entry and exit the x register points to the last byte read from the
;; sector buffer, in ascending order from $00 to $ff. meaning that on init
;; x should be $ff if the first sector has yet to be transferred and
;; lz_fetch_sector should be called first-off. similarly the shift register
;; should initially be emptied by setting lz_bits to #$80.
;;
;; the point of this scheme is that several compressed blocks or other data
;; can be packed end-to-end instead of requiring things to be aligned on
;; sector boundaries
;;
;; finally there's a crude but effective way to use sliding-windows.
;; recall that the caller is responsible for advancing the destination pointer,
;; and thus also needs wrap it when necessary. furthermore the compressor has
;; to be told of a limited window-size so it doesn't try to use matches beyond
;; it or, and this is an important point, matches spanning the window boundary.
;;
;; then the one thing that's left for the decruncher to do is to wrap
;; backwards references when subtracting the offset from the current output
;; position. the easiest way to achieve this is to make the window a nice even
;; power-of-two and place it on a an odd address, then fix up the high-byte
;; with a single ORA. in other words ORA #$10 would work for a 4k window
;; placed at $1000/$3000/$5000/$7000/$9000/$a000/$f000.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


                ;;;;;;;; fetch some more bits to work with ;;;;;;;;

        :       jsr lz_fetch_sector
                .byte $a0               ;; ldy #$e8
refill_bits:    inx
                beq :-
lz_sector0 = *+1
                ldy lz_sector,x
                sty lz_bits
        ;;      sec
                rol lz_bits
upper_rts:      rts


                ;;;;;;;; finish processing a literal run ;;;;;;;;

        :       jsr lz_fetch_sector
                .byte $a9               ;; lda #$e8
lcopy:          inx
                beq :-
lz_sector1 = *+1
                lda lz_sector,x
                dey
                sta (lz_dst),y
                bne lcopy

                lda lz_scratch          ;; advance destination pointer
                clc
                adc lz_dst_lo
                sta lz_dst_lo
                bcs upper_rts
                
.if BYTESTREAM
                jsr maybegetblock
.endif; BYTESTREAM

                ;; one literal run following another only makes sense if the
                ;; first run is of maximum length and had to be split. yet any
                ;; 256-byte must by definition cross the page, so here we can
                ;; safely omit the type bit


                ;;;;;;;; process match ;;;;;;;;

do_match:       lda #%00100000          ;; determine offset length by a
        :       asl lz_bits             ;; two-bit prefix combined with the
                bne :+                  ;; first run length bit (where a one
                jsr refill_bits         ;; identifies two-byte match).
        :       rol                     ;; the rest of the length bits will
                bcc :--                 ;; then follow *after* the offset data

                tay
                lda moff_length,y
                beq moff_far

moff_loop:      asl lz_bits             ;; load partial offset byte
                bne :+
                sty lz_scratch
                jsr refill_bits
                ldy lz_scratch
        :       rol
                bcc moff_loop

                bmi moff_near

moff_far:       sta lz_scratch          ;; save the bits we just read as the
                                        ;; high-byte

                inx                     ;; for large offsets we can load the
                bne :+                  ;; low-byte straight from the stream
                jsr lz_fetch_sector     ;; without going throught the shift
lz_sector2 = *+1
        :       lda lz_sector,x         ;; register

         ;;     sec
                adc moff_adjust_lo,y
                bcs :+
                dec lz_scratch
                sec
        :       adc lz_dst_lo
                sta match_lo

                lda lz_scratch
                adc moff_adjust_hi,y
                sec
                jmp moff_join

        ;;      sec
moff_near:      adc moff_adjust_lo,y
        ;;      sec
                adc lz_dst_lo
                sta match_lo
                lda #$ff                ;;    ____
moff_join:      adc lz_dst_hi           ;;   /   /
                                        ;;  /   /___
;; lz_window    = *+1                   ;; /        | insert sliding-window
;;              ora #$00                ;; \    ____| wrapping code here
                                        ;;  \   \ 
                sta match_hi            ;;   \___\ 

                cpy #$04                ;; get any remaning run length bits
                lda #$01
                bne mrun_enter          ;; (bra)

        :       jsr refill_bits
mrun_enter:     bcs mrun_gotten
mrun_loop:      asl lz_bits
                bne :+
                jsr refill_bits
        :       rol
                asl lz_bits
                bcc mrun_loop
                beq :--

mrun_gotten:    tay                     ;; a 257-byte (=>$00) run serves as
                beq end_of_file         ;; a sentinel

                sta mcopy_len

                ldy #$ff                ;; copy loop. this needs to be run
mcopy:          iny                     ;; forwards since RLE-style matches
match_lo        = *+1                   ;; can overlap the destination
match_hi        = *+2
                lda $ffff,y
                sta (lz_dst),y
mcopy_len       = *+1
                cpy #$ff
                bne mcopy

                tya                     ;; advance destination pointer
        ;;      sec
                adc lz_dst_lo
                sta lz_dst_lo
                bcs lower_rts

.if BYTESTREAM
                jsr maybegetblock
.endif; BYTESTREAM

lz_decrunch:    asl lz_bits             ;; literal or match to follow?
                bcs :++
        :       jmp do_match
typeof_refill:  jsr refill_bits
                bcc :-
        :       beq typeof_refill


                ;;;;;;;; process literal run ;;;;;;;;

do_literal:     lda #%00000001          ;; decode run length
                bne lrun_enter          ;; (bra)

        :       jsr refill_bits
                bcs lrun_gotten
lrun_loop:      asl lz_bits
                bne :+
                jsr refill_bits
        :       rol
lrun_enter:     asl lz_bits
                bcc lrun_loop
                beq :--

lrun_gotten:    sta lz_scratch
                tay
                jmp lcopy


                ;;;;;;;; offset coding tables ;;;;;;;;

                ;; this length table is a bit funky. the idea here is to use
                ;; the value as an initial shifter register instead of keeping
                ;; a separate counter. in other words we iterate until the
                ;; leading one is shifter out. then afterwards the bit just
                ;; below it (our new sign bit) is set if the offset is shorter
                ;; than 8-bits, and conversely it's cleared if we need to
                ;; fetch a separate low-byte as well.
                ;; the fact that the sign bit is cleared as a flag is
                ;; compensated for in the off_adjust_hi table.

moff_length:    .byte %00011111         ;; 4  -.
                .byte %00000111         ;; 6   |_ long (>2 byte matches)
                .byte %10111111         ;; 9   |
                .byte %00010111         ;; 12 -'

                .byte %00111111         ;; 3  -.
                .byte %00000111         ;; 6   |_ short (2 byte matches)
                .byte %00000000         ;; 8   |
                .byte %01011111         ;; 10 -'

moff_adjust_lo: .byte %11111110
                .byte %11101110
                .byte %10101110
                .byte %10101110

                .byte %11111110
                .byte %11110110
                .byte %10110110
                .byte %10110110

moff_adjust_hi  = *-2
        ;;      .byte %11111111         ;; -._ two-byte hole
        ;;      .byte %11111111         ;; -'
                .byte %01111111
                .byte %01111101

end_of_file:    clc                     ;; -._ two-byte hole
lower_rts:      rts                     ;; -'
                .byte %11111110
                .byte %01111110
