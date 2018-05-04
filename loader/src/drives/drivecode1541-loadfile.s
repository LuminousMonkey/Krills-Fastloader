
; this module loads a file

.ifdef MODULE
    .include "cpu.inc"
    .include "via.inc"

    __NO_LOADER_SYMBOLS_IMPORT = 1
    .include "loader.inc"
    .include "drives/drivecode1541-kernel.inc"
    .include "drives/drivecode-common.inc"
    .include "kernelsymbols1541.inc"

    .org RUNMODULE - 3

    ; module header
    .word * - 2
    .byte (MODULEEND - MODULESTART + 3) / 256 + 1; number of module blocks, not quite accurate, but works for now

MODULESTART:

.else; !MODULE
     .export blocksize : absolute
.endif; !MODULE

TEMPTRACKLINKTAB         = $0780
TEMPSECTORLINKTAB        = $07c0

NEXTSECTOR               = UNUSED_ZP0
SECTORCOUNT              = UNUSED_ZP1

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) && (LOAD_ONCE = 0)
    HASHVALUE0LO         = TRACKLINKTAB + 1
    HASHVALUE0HI         = TRACKLINKTAB + 2
    HASHVALUE1LO         = TRACKLINKTAB + 3
    HASHVALUE1HI         = TRACKLINKTAB + 4
    FILENAME             = TRACKLINKTAB + 5; max. $10 bytes

    CURRDIRBLOCKSECTOR   = UNUSED_ZP2
    CYCLESTARTENDSECTOR  = UNUSED_ZP3
    NEXTDIRBLOCKSECTOR   = LOWMEM + 0
    DIRCYCLEFLAG         = LOWMEM + 1
    WRAPFILEINDEX        = LOWMEM + 2

    DIRBUFFER            = LOWMEM + 3
    DIRBUFFSIZE          = (LOWMEMEND - DIRBUFFER) / 4;
    DIRTRACKS            = DIRBUFFER
    DIRSECTORS           = DIRTRACKS + DIRBUFFSIZE
    FILENAMEHASHVAL0     = DIRSECTORS + DIRBUFFSIZE
    FILENAMEHASHVAL1     = FILENAMEHASHVAL0 + DIRBUFFSIZE
    DIRBUFFEND           = FILENAMEHASHVAL1 + DIRBUFFSIZE

    DIRBUFFSIZE41        = DIRBUFFSIZE
    .export DIRBUFFSIZE41

            .assert !(((LOWMEMEND - DIRBUFFER) & 3) = 1), error, "***** 1 wasted code byte. *****"
            .assert !(((LOWMEMEND - DIRBUFFER) & 3) = 2), error, "***** 2 wasted code bytes. *****"
            .assert !(((LOWMEMEND - DIRBUFFER) & 3) = 3), error, "***** 3 wasted code bytes. *****"
            
            .assert DIRBUFFSIZE >= 9, error, "***** Dir buffer too small. *****"

.endif; (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) && (LOAD_ONCE = 0)


.if !LOAD_ONCE
    .if ::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME

            GET_FILENAME 1541

    .elseif ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR

            jsr dgetbyte; get starting track
            sta FILETRACK
            jsr dgetbyte; get starting sector
            jsr drwaitrkch; disables watchdog
            sta FILESECTOR

    .else
            .error "***** Error: The selected file system option is not yet implemented. *****"
    .endif
.endif; !LOAD_ONCE

.if (::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR) | LOAD_ONCE
            ; check for illegal track or sector
            ldy FILETRACK
            beq toillegal + $00
            cpy #MAXTRACK41 + 1
            bcs toillegal + $01
            jsr getnumscts
            dex
            cpx FILESECTOR
            bcs :+
toillegal:  sec
            jmp illegalts
:
.endif; (::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR) | LOAD_ONCE

            lda #OPC_BIT_ZP; disable error
            sta cmpidswtch ; on ID mismatch
spinuploop: ldy #ANYSECTOR; get any block on the current track, no sector link sanity check,
            jsr getblcurtr; don't store id, check after return
            bcs spinuploop; retry until any block has been loaded correctly

.if LOAD_ONCE = 0
            lda #OPC_BNE  ; enable error
            sta cmpidswtch; on ID mismatch
.endif

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) && (!LOAD_ONCE)

            ; matches against hash of filename in FILENAMEHASH0/1
            FIND_FILE 1541
            ; sets a to file track and y to file sector, sets carry flag

.else; ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR && (!LOAD_ONCE)

    .if LOAD_ONCE
:           lda CURTRACK
            ldy #ANYSECTOR; no sector link sanity check
            jsr getblkchid; compare id
            bcs :-
            lda #$00; clear new disk flag
            sta DISKCHANGED
            bcc spinuploop
    .else
            ; always consider disk as a new disk

            ; store new disk id
:           lda CURTRACK
            ldy #ANYSECTOR; no sector link sanity check
            jsr getblkstid; store id
            bcs :-
            lda #$00; clear new disk flag
            sta DISKCHANGED
    .endif; !LOAD_ONCE

    .if LOAD_ONCE
            lda #OPC_BNE  ; enable error
            sta cmpidswtch; on ID mismatch
    .endif
            jsr busyledon; passes errorretlo, returns with carry set
            lda FILETRACK
            ldy FILESECTOR

.endif; !(::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR) | LOAD_ONCE

            ; a contains the file's starting track here
            ; y contains the file's starting sector here
            ldx #$00
            stx BLOCKINDEXBASE
           ;sec; load first block in order to determine
               ; the file's load address
trackloop:  php; out-of-order flag
            sty SECTORTOFETCH
            ; x = amount of blocks on the previous track
            pha; next track
            txa
            clc
            adc BLOCKINDEXBASE
            sta BLOCKINDEXBASE
            pla; next track
            jsr trackseek

            ; scan the track for the file links
            ; x contains the total number of blocks on this track
           ;lda #SECTORISPROCESSED      ; the accu contains a negative number
:           sta TRACKLINKTAB - $01,x    ; mark all sectors as processed, the scan loop will
            sta TEMPTRACKLINKTAB - $01,x; put sector numbers to the corresponding indices
            dex
            bne :-
scantrloop: lda #OPC_BIT_ZP; only fetch the first few bytes to track the block links
            ; this is a weak point since there is no data checksumming here -
            ; however, sector link sanity is checked
            ldy #ANYSECTORSANELINK; sector link sanity check
            sty REQUESTEDSECTOR
            jsr getblkscan; when loading by T&S: 1st rev: store id, 2nd rev: compare id
            bcs scantrloop; branch until fetch successful
           ;ldx LOADEDSECTOR
           ;lda LINKTRACK; illegal tracks are checked after
                         ; this track has been processed
            sta TEMPTRACKLINKTAB,x; store the sector's track link and mark it
                                  ; as processed
           ;ldy LINKSECTOR
            tya
            sta TEMPSECTORLINKTAB,x

            ; go through the link list to find the blocks's order on the track
            ldy #$00
            ldx SECTORTOFETCH; first file block on this track
            stx LINKSECTOR
:           lda TEMPTRACKLINKTAB,x
            bmi scantrloop; branch if not all of the file's blocks on this track
                          ; have been scanned yet
            sty TRACKLINKTAB,x; store sector index
            iny; increase sector index
            pha; link track
            lda TEMPSECTORLINKTAB,x; get link sector
            tax
            pla; link track
            cmp CURTRACK; check whether link track is the current track
            beq :-      ; branch until all the file's blocks on the current
                        ; track have been ordered
                        ; loops in the link graph are not detected and will cause an endless loop

            ; the track's sector links are scanned now

            plp; out-of-order flag
            ; read and transfer all the blocks that belong to the file
            ; on the current track, the blocks are read in quasi-random order
            pha         ; next track
            tya         ; amount of the file's blocks on the current track
            pha
            stx NEXTSECTOR; first sector on the next track
            sty SECTORCOUNT; amount of the file's blocks on the current track

blockloop:  ldy #UNPROCESSEDSECTOR; find any yet unprocessed block belonging to the file
            bcc loadooo; carry clear: load out-of-order
            ldy LINKSECTOR; load the next block in order, this happens only for the first file block

.if ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR
            ; for the first file block, store ID
            sty SECTORTOFETCH
:           lda CURTRACK
            ldy SECTORTOFETCH; negative: any unprocessed sector, positive: this specific sector; sector link sanity check
            jsr getblkstid   ; read any of the files's sectors on the current track, store id
            bcs :-           ; retry until a block has been successfully loaded
            bcc transfer
.endif; ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR

loadooo:    sty SECTORTOFETCH
:           ldy SECTORTOFETCH; negative: any unprocessed sector, positive: this specific sector; sector link sanity check
            jsr getblcurtr   ; read any of the files's sectors on the current track, compare id
            bcs :-           ; retry until a block has been successfully loaded

transfer:   ; send the block over
            jsr prepareblk
           ;clc
            lda BLOCKINDEX
            adc BLOCKINDEXBASE
            jsr sendblock; send the block over, this decreases SECTORCOUNT
            ; carry-flag is cleared if the next block may be loaded out of order
            lda SECTORCOUNT; sector count for the current track
            bne blockloop

            ldy NEXTSECTOR
            pla; amount of the file's blocks on the current track
            tax
            pla; next track
            ; carry-flag is cleared if the next block may be loaded out of order
.if ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR
            beq :+
            jmp trackloop; process next track
:
.else
            bne trackloop; process next track
.endif; ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR

            ; loading is finished

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) && (!LOAD_ONCE)

            PREPARE_NEXT_FILE 1541

            clc; all ok after loading

filenotfnd: ; branches here with carry set
.else
            clc; all ok after loading
.endif

illegalts:  ; carry set: file not found or illegal t or s
            jsr sendstatus

            ldy #$01; turn motor and busy led off
            lda #BUSY_LED; check if busy led is lit
            and VIA2_PRB
            beq :+
            ldy #$ff; fade off the busy led, then turn motor off
.if LOAD_ONCE
:           jmp duninstall
.else
:           ENABLE_WATCHDOG
:           bit VIA1_PRB; check for ATN in to go high:
            bpl :-      ; wait until the computer has acknowledged the file transfer
            sei; disable watchdog
            jmp driveidle
.endif

.if ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR
            .res 64; prevent page-boundary crossing below
.endif

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) && (!LOAD_ONCE)

            FNAMEHASH 1541

.endif; ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR && (!LOAD_ONCE)

            ; carry: clear = ok, set = load error
sendstatus: lda #$00
            sta SECTORCOUNT; make sure DATA OUT (track change) is not raised after transferring the status
            sta blocksize + $01; just send over one byte
            sbc #$01; carry clear: result is $00 - $02 = $fe - loading finished successfully
                    ; carry set:   result is $00 - $01 = $ff - load error

            ; accu: block index or status byte
sendblock:  ldy #$00
            jsr gcrencode; block index or status byte

            ; send block ready signal and wait for
            ; signal to begin transferring the block
            ldx #$10; here, the watchdog timer is polled manually because
                    ; an extra-long time-out period is needed since the computer may
                    ; still be busy decompressing a large chunk of data;
                    ; this is the round counter
            dey; ldy #$ff
            lda #DATA_OUT; drop CLK but leave DATA high as signal of presence
            sta VIA1_PRB; block ready signal
            bne :+; jmp
            ; a watchdog is used because the computer might be reset while sending
            ; over the block, leaving the drive waiting forever for handshake pulses
waitready:  lda WATCHDOG_TIMER; see if the watchdog barked
            bne :++
            dex               ; if yes, decrease the round counter
.if DISABLE_WATCHDOG
            beq nowatchdog
nowatchdog:
.else
            beq timeout; and trigger watchdog on time-out
.endif
:           sty WATCHDOG_TIMER; reset watchdog time-out and clear IRQ flag
:           bit VIA1_PRB
            bpl waitready; wait for ATN = high

            sty WATCHDOG_TIMER; reset watchdog time-out and clear possibly set IRQ flag

timeout:    ENABLE_WATCHDOG
            iny; ldy #$00

.if ::PROTOCOL = PROTOCOLS::TWO_BITS_RESEND

resend:     lda #CLK_OUT                  ; 2
            sta VIA1_PRB                  ; 4
:           bit VIA1_PRB                  ; 4 - sync: wait for ATN high
            bpl :-                        ; 3

sendloop:   ldx LONIBBLES,y               ; 4
            lda SENDGCRTABLE,x            ; 4 - zp access
            ldx HINIBBLES,y               ; 4
:           bit VIA1_PRB                  ; 4 - sync: wait for ATN low
            bmi :-                        ; 3
                                          ; = 42

            sta VIA1_PRB                  ; 4
            asl                           ; 2
            and #.lobyte(~ATNA_OUT)       ; 2
            sta VIA1_PRB                  ; 4
            lda SENDGCRTABLE,x            ; 4 - zp access
            sta VIA1_PRB                  ; 4
            asl                           ; 2
            and #.lobyte(~ATNA_OUT)       ; 2
            sta VIA1_PRB                  ; 4
                                          ; = 28

            lda #$e0 | DATA_OUT | DATA_IN ; 2
blocksize:  cpy #$00                      ; 2
            sta VIA1_PRB                  ; 4
            sta WATCHDOG_TIMER            ; 4 - reset watchdog time-out
            bit VIA1_PRB                  ; 4
            bpl resend                    ; 2
            iny                           ; 2
            bcc sendloop                  ; 3
                                          ; = 70

.else; ::PROTOCOL != PROTOCOLS::TWO_BITS_RESEND

sendloop:   ldx LONIBBLES,y               ; 4
            lda SENDGCRTABLE,x            ; 4 - zp access
                                          ; = 22 (20 on computer)

:           bit VIA1_PRB                  ; 4 - sync 4: wait for ATN low
            bmi :-                        ; 3 - first byte: wait for end of ATN strobe
            sta VIA1_PRB                  ; 4
            asl                           ; 2
            ora #ATNA_OUT                 ; 2 - next bit pair will be transferred with ATN high - if not set, host DATA IN will be low
            ldx HINIBBLES,y               ; 4
                                          ; = 19 (22 on computer)

:           bit VIA1_PRB                  ; 4 - sync 1: wait for ATN high
            bpl :-                        ; 3
            sta VIA1_PRB                  ; 4
            lda SENDGCRTABLE,x            ; 4 - zp access
            sta WATCHDOG_TIMER            ; 4 - reset watchdog time-out
                                          ; = 19 (19 on computer)

:           bit VIA1_PRB                  ; 4 - sync 2: wait for ATN low
            bmi :-                        ; 3
            sta VIA1_PRB                  ; 4
            asl                           ; 2
            ora #ATNA_OUT                 ; 2 - next bit pair will be transferred with ATN high - if not set, host DATA IN will be low
blocksize:  cpy #$00                      ; 2
            iny                           ; 2
                                          ; = 19 (19 on computer)

:           bit VIA1_PRB                  ; 4 - sync 3: wait for ATN high
            bpl :-                        ; 3
            sta VIA1_PRB                  ; 4
            bcc sendloop                  ; 3
                                          ; = 79, 7 more than the theoretical limit at 18 cycles per bitpair

.endif; ::PROTOCOL != PROTOCOLS::TWO_BITS_RESEND

            .assert .hibyte(* + 1) = .hibyte(sendloop), error, "***** Page boundary crossing in byte send loop, fatal cycle loss. *****"

:           bit VIA1_PRB; wait for acknowledgement
            bmi :-      ; of the last data byte

            ldy #CLK_OUT; not changing tracks
            dec SECTORCOUNT
            bne :+      ; pull DATA_OUT high when changing tracks
drwaitrkch: ldy #CLK_OUT | DATA_OUT; flag track change
:           clc; out-of-order flag
            ; it is only possible to load the file's first blocks in order and then switch
            ; to loading out of order - switching back to loading in order will cause
            ; the stream code to hiccup and thus faulty file data to be loaded
            jmp drivebusy; will announce busy and track change flag, disable watchdog and perform rts
.ifdef MODULE
MODULEEND:
.endif

LOADFILE41END = *
.export LOADFILE41END

            .assert * <= LONIBBLES, error, "***** 1541 drive code too large. *****"
