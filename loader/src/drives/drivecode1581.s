
.include "cpu.inc"
.include "cia.inc"
.include "via.inc"

.include "drives/drivecode-common.inc"


BUFFER                = $00
SYS_SP                = $01
JOBCODESTABLE         = $02; fixed in ROM
JOBTRKSCTTABLE        = $0b; fixed in ROM - $0b..$1c
FILETRACK             = $0b
FILESECTOR            = $0c
FILENAMEHASH0         = FILETRACK
FILENAMEHASH1         = FILESECTOR
.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (!LOAD_ONCE)
FILEINDEX             = FILETRACK
.endif
HASHVALUE0LO          = $0d
HASHVALUE0HI          = $0e
HASHVALUE1LO          = $0f
HASHVALUE1HI          = $10
NUMFILES              = $11
CURRDIRBLOCKTRACK     = $12
CURRDIRBLOCKSECTOR    = $13
CYCLESTARTENDTRACK    = $14
CYCLESTARTENDSECTOR   = $15
DIRCYCLEFLAG          = $16
;BLOCKBUFFERJOBTRACK  = $17; fixed in ROM - track for job at buffer 6 ($0900)
;BLOCKBUFFERJOBSECTOR = $18; fixed in ROM - sector for job at buffer 6 ($0900)
BLOCKINDEX            = $19
NEXTDIRBLOCKTRACK     = $1a
NEXTDIRBLOCKSECTOR    = $1b
FIRSTDIRSECTOR        = $1c

DRIVESTATE            = $26; fixed in ROM
DRIVEOFF              = $00; literal
OPEN_FILE_TRACK       = $4c; fixed in ROM
SYSIRQVECTORBUF_LO    = $5e
SYSIRQVECTORBUF_HI    = $5f
WRAPFILEINDEX         = $63

LED_FLAG              = $79
IRQVECTOR_LO          = $0192
IRQVECTOR_HI          = $0193
HDRS2                 = $01bc
DIRTRACK81            = $022b
OPEN_FILE_SECTOR      = $028b
DIRSECTOR81           = $00; literal

STROBE_CONTROLLER     = $ff54

READ_DV               = $80
MOTOFFI_DV            = $8a
SEEK_DV               = $8c

OK_DV                 = $00

BUFFER0               = $0300
BUFFERSIZE            = $0100

BLOCKBUFFER           = $0900
TRACKOFFSET           = $00
SECTOROFFSET          = $01
SENDTABLELO           = $0a00
SENDTABLEHI           = $0b00

LINKTRACK             = BLOCKBUFFER + TRACKOFFSET
LINKSECTOR            = BLOCKBUFFER + SECTOROFFSET

BINARY_NIBBLE_MASK    = %00001111

ROMOS_MAXTRACK        = $8f; MAXTRACK81 - 1
ROMOS_MAXSECTOR       = $75; MAXSECTOR81 + 1
MAXTRACK81            = 80; literal
MAXSECTOR81           = 39; literal

.if !DISABLE_WATCHDOG
RESET_TIMERB          = $cb9f
WATCHDOG_PERIOD       = $20; 32 * 65536 cycles at 2 MHz = 1.049 s
CONTROLLERIRQPERIODFD = $4e20
    .macro INIT_CONTROLLER
            jsr initcontrl
    .endmacro
.else
    .macro INIT_CONTROLLER
    .endmacro
.endif

BUFFERINDEX           = (BLOCKBUFFER - BUFFER0) / BUFFERSIZE


            .org $0300


.if UNINSTALL_RUNS_DINSTALL
    .export drvcodebeg81 : absolute
    .export drivebusy81  : absolute
.endif; UNINSTALL_RUNS_DINSTALL


.export cmdfdfix0 : absolute
.export cmdfdfix1 : absolute
.export cmdfdfix2 : absolute
.if !DISABLE_WATCHDOG
.export cmdfdfix3 : absolute
.export cmdfdfix4 : absolute
.endif

drvcodebeg81: .byte .hibyte(drivebusy81 - * + $0100 - $01); init transfer count hi-byte

SENDNIBBLETAB:
            BIT0DEST = 3
            BIT1DEST = 1
            BIT2DEST = 2
            BIT3DEST = 0

            .repeat $10, I
                .byte (((~I >> 0) & 1) << BIT0DEST) | (((~I >> 1) & 1) << BIT1DEST) | (((~I >> 2) & 1) << BIT2DEST) | (((~I >> 3) & 1) << BIT3DEST)
            .endrep

filename:   ; note: this is not in the zero-page

dcodinit:   tsx
            stx SYS_SP
.if !DISABLE_WATCHDOG
            lda IRQVECTOR_LO
            sta SYSIRQVECTORBUF_LO
            lda IRQVECTOR_HI
            sta SYSIRQVECTORBUF_HI
.endif

.if LOAD_ONCE
            jsr drivebusy81; signal idle to the computer
:           lda CIA_PRB
            and #ATN_IN | ATNA_OUT | CLK_OUT | CLK_IN | DATA_OUT | DATA_IN
            cmp #ATN_IN |            CLK_OUT | CLK_IN |            DATA_IN
            bne :-; no watchdog
            ; the busy led might be enabled
            lda #DRIVE_LED
            bit CIA_PRA
            beq :++
            ; turn it off if so
            ldx #$ff
:           jsr fadeled
            txa
            bne :-
:
.else; !LOAD_ONCE

            jsr motrledoff

.endif; LOAD_ONCE

            ldx #$00
:           txa
            and #BINARY_NIBBLE_MASK
            tay
            lda SENDNIBBLETAB,y
            sta SENDTABLELO,x
            txa
            lsr
            lsr
            lsr
            lsr
            tay
            lda SENDNIBBLETAB,y
            sta SENDTABLEHI,x
            inx
            bne :-

.if !DISABLE_WATCHDOG
            lda cmdfdfix2; 0 for FD
            beq :+
            ; watchdog initialization
            lda #$ff
            sta CIA_TA_LO
            sta CIA_TA_HI
            lda #COUNT_PHI2 | FORCE_LOAD | CONTINUOUS | TIMER_START
            sta CIA_CRA
            jsr initwatchd
            lda #CIA_CLR_INTF | EVERY_IRQ
            sta CIA_ICR
            lda #CIA_SET_INTF | TIMERB_IRQ
            sta CIA_ICR
            bne :++
:           jsr initwatchd
:
.endif

.if UNINSTALL_RUNS_DINSTALL
            lda #.hibyte(drvcodebeg81 - $01)
            sta dgetputhi
            lda #OPC_BIT_ZP
            sta instalwait
.endif; UNINSTALL_RUNS_DINSTALL

            ldx #$00

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (!LOAD_ONCE)
            stx NUMFILES
.endif

.if !LOAD_ONCE
            jsr drivebusy81; signal idle to the computer
:           lda CIA_PRB
            and #ATN_IN | ATNA_OUT | CLK_OUT | CLK_IN | DATA_OUT | DATA_IN
            cmp #ATN_IN |            CLK_OUT | CLK_IN |            DATA_IN
            bne :-; no watchdog
.endif; !LOAD_ONCE

drividle:   jsr fadeled; fade off the busy led
            lda CIA_PRB
            and #ATN_IN | ATNA_OUT | CLK_OUT | CLK_IN | DATA_OUT | DATA_IN
            cmp #ATN_IN |            CLK_OUT | CLK_IN |            DATA_IN
            beq drividle; wait until there is something to do

            cmp #                    CLK_OUT | CLK_IN |            DATA_IN
            beq :+
            jmp duninstall; check for reset or uninstallation

            ; load a file

:           txa
            beq beginload; check whether the busy led has been completely faded off
            jsr busyledon; if not, turn it on
beginload:

.if !LOAD_ONCE
    .if !DISABLE_WATCHDOG
            jsr enablewdog; enable watchdog, the computer might be reset while sending over a
                          ; byte, leaving the drive waiting for handshake pulses
    .endif; !DISABLE_WATCHDOG

    .if ::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME

            GET_FILENAME 1581

            ; matches against hash of filename in FILENAMEHASH0/1
            FIND_FILE 1581
	        ; sets a to file track and y to file sector
            tax

    .elseif ::FILESYSTEM = FILESYSTEMS::TRACK_SECTOR

            jsr dgetbyte; get starting track
            tax
            jsr dgetbyte; get starting sector
            jsr drwaitrkch; disables watchdog
            tay
            txa

    .endif

.else; LOAD_ONCE
            ldy OPEN_FILE_SECTOR
            ldx OPEN_FILE_TRACK
.endif; LOAD_ONCE

            ; check for illegal track or sector
            beq toillegal + $00

            dex; 79->77 cmp 79 -> bcc
            dex; 80->78 cmp 79 -> bcc
               ; 81->80 cmp 79 -> bcs
            cpx ROMOS_MAXTRACK; #MAXTRACK81 - 1
            inx
            inx
            bcs toillegal + $01
            cpy ROMOS_MAXSECTOR; #MAXSECTOR81 + 1
            bcc :+
toillegal:  sec
cmdfdfix0:  jmp illegalts; is changed to bit illegalts on FD2000/4000 to disable illegal track or sector error,
                         ; ROM variables for logical track/sector boundaries aren't known (probably around MAXTRACKFD = $54)

:           tya
            pha
            jsr busyledon
            pla
            tay; FILESECTOR
            txa; FILETRACK

            ldx #$00
            stx BLOCKINDEX
loadblock:  sta JOBTRKSCTTABLE + (2 * BUFFERINDEX) + TRACKOFFSET
            sty JOBTRKSCTTABLE + (2 * BUFFERINDEX) + SECTOROFFSET
:           jsr getblockag
            bcs :-

           ;ldy LINKSECTOR
           ;lda LINKTRACK
            pha
            beq :+
            ldy #$ff
:           lda LINKSECTOR
            pha
            sty blocksize + $01
            dey
            dey
            sty BLOCKBUFFER + $01; block length
            lda BLOCKINDEX
            jsr sendblock; send the block over
            inc BLOCKINDEX
            pla; LINKSECTOR
            tay
            pla; LINKTRACK
            bne loadblock

            ; loading is finished

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (LOAD_ONCE = 0)

            PREPARE_NEXT_FILE 1581

            clc; all ok after loading

filenotfnd: ; branches here with carry set

.else
            clc; all ok after loading
.endif

illegalts:  ; or illegal t or s

            jsr sendstatus

            ldx #$01; turn motor and busy led off
            lda #DRIVE_LED; check if busy led is lit
            and CIA_PRA
            beq :+
            ldx #$ff; fade off the busy led, then turn motor off
.if LOAD_ONCE
:
            jmp duninstall
.else
    .if !DISABLE_WATCHDOG
:           jsr enablewdog
    .endif
:           bit CIA_PRB; check for ATN in to go high:
            bpl :-     ; wait until the computer has acknowledged the file transfer
            sei; disable watchdog
            jmp drividle
.endif

.if !DISABLE_WATCHDOG
initcontrl: lda SYSIRQVECTORBUF_LO
            sta IRQVECTOR_LO
            lda SYSIRQVECTORBUF_HI
            sta IRQVECTOR_HI
            lda cmdfdfix2; 0 for FD
            beq :+
            jmp RESET_TIMERB
:           lda #.lobyte(CONTROLLERIRQPERIODFD)
            sta VIA_T1C_L
            lda #.hibyte(CONTROLLERIRQPERIODFD)
            sta VIA_T1C_H
            rts
.endif

cmdfdfix1 = * + 1
cmdfdfix2 = * + 2
getdirtrk:  lda DIRTRACK81
            rts

trackseek:  tax
            dex
            stx HDRS2 + (2 * BUFFERINDEX)
            INIT_CONTROLLER
            lda #SEEK_DV
            ldx #BUFFERINDEX
.if DISABLE_WATCHDOG
            jmp STROBE_CONTROLLER; move head to the start track of the next file in the
                                 ; directory

.else; !DISABLE_WATCHDOG
            jsr STROBE_CONTROLLER; move head to the start track of the next file in the
                                 ; directory

            ; fall through

initwatchd: ; the i-flag is set here
            lda #.lobyte(watchdgirq)
            sta IRQVECTOR_LO
            lda #.hibyte(watchdgirq)
            sta IRQVECTOR_HI
            lda cmdfdfix2; 0 for FD
            beq :+
            lda #.lobyte(WATCHDOG_PERIOD)
            sta CIA_TB_LO
            lda #.hibyte(WATCHDOG_PERIOD)
            sta CIA_TB_HI
:           rts

enablewdog: lda cmdfdfix2; 0 for FD
            beq :+
            lda #COUNT_TA_UNDF | FORCE_LOAD | ONE_SHOT | TIMER_START
            sta CIA_CRB
            bit CIA_ICR
            ENABLE_WATCHDOG
            rts            
:           lda #IRQ_CLEAR_FLAGS | IRQ_ALL_FLAGS
            sta VIA_IER; no IRQs from VIA
            lda #IRQ_SET_FLAGS | IRQ_TIMER_1
            sta VIA_IER; timer 1 IRQs from VIA
            lda #$ff
            sta VIA_T1C_H
            ENABLE_WATCHDOG
            rts
.endif; !DISABLE_WATCHDOG

busyledon:  lda #DRIVE_LED
            ora CIA_PRA
            ldy #$ff
            bne store_cia; jmp

fadeled:    txa
            tay
            beq ledisoff
:           nop
            bit OPC_BIT_ZP
            iny
            bne :-
            pha
            jsr busyledon
            pla
            tay
:           nop
            bit OPC_BIT_ZP
            dey
            bne :-
            dex
            bne busyledoff

motrledoff: ; turn off motor
            txa
            pha
            INIT_CONTROLLER
            lda #MOTOFFI_DV
            ldx #BUFFERINDEX
            jsr STROBE_CONTROLLER
            lda #DRIVEOFF
            sta DRIVESTATE
            pla
            tax

busyledoff: lda CIA_PRA
            and #.lobyte(~DRIVE_LED); turn off drive led
            ldy #$00
store_cia:  sta CIA_PRA
            sty LED_FLAG
ledisoff:   rts

getblock:   sta JOBTRKSCTTABLE + (2 * BUFFERINDEX) + TRACKOFFSET
            sty JOBTRKSCTTABLE + (2 * BUFFERINDEX) + SECTOROFFSET
getblockag: INIT_CONTROLLER
            lda #READ_DV
            ldx #BUFFERINDEX
            jsr STROBE_CONTROLLER

.if !DISABLE_WATCHDOG
            jsr initwatchd
.endif

            lda JOBCODESTABLE + BUFFERINDEX; FD does not return the error status in the accu
            cmp #OK_DV + 1

            ; the link track is returned last so that the z-flag
            ; is set if this block is the file's last one
            ldy LINKSECTOR
            ldx JOBTRKSCTTABLE + (2 * BUFFERINDEX) + SECTOROFFSET; LOADEDSECTOR
            lda LINKTRACK
            rts

.if !UNINSTALL_RUNS_DINSTALL

    .if !DISABLE_WATCHDOG

watchdgirq: ldx #$ff

    .endif; !DISABLE_WATCHDOG

duninstall: txa
            beq :+
            jsr busyledon
            lda #$ff; fade off the busy led
:           pha
            jsr getdirtrk
            jsr trackseek
            pla
            tax
:           jsr fadeled
            txa
            bne :-
            ldx SYS_SP
            txs
            INIT_CONTROLLER
            rts

.else; UNINSTALL_RUNS_DINSTALL

    .if !DISABLE_WATCHDOG

watchdgirq: jsr busyledon
            jsr getdirtrk
            jsr trackseek
            ; fade off the busy led and reset the drive
            ldx #$ff
:           jsr fadeled
            txa
            bne :-
            ldx SYS_SP
            txs
            INIT_CONTROLLER
            rts

    .endif; !DISABLE_WATCHDOG

duninstall:
:           jsr fadeled
            txa
            bne :-
            ldx SYS_SP
            txs
            INIT_CONTROLLER
            jmp dinstall

.endif; UNINSTALL_RUNS_DINSTALL

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (!LOAD_ONCE)

            FNAMEHASH 1581

.endif; (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (!LOAD_ONCE)

            ; carry: clear = ok, set = load error
sendstatus: lda #$00
            sta blocksize + $01
            sbc #$01; carry clear: result is $00 - $02 = $fe - loading finished successfully
                    ; carry set:   result is $00 - $01 = $ff - load error
            sta JOBTRKSCTTABLE + (2 * BUFFERINDEX) + TRACKOFFSET; make sure DATA OUT (track change) is not
                                                                ; raised after transferring the status

sendblock:  sta BLOCKBUFFER + $00; block index
.if !DISABLE_WATCHDOG
            jsr enablewdog
.endif
            lda #DATA_OUT
            sta CIA_PRB; block ready signal
waitready:  bit CIA_PRB
            bpl waitready

.if ::PROTOCOL = PROTOCOLS::TWO_BITS_RESEND

            ldy #$00
            beq sendloop; jmp
resend:     stx CIA_PRB                                              ; 4
            dey                                                      ; 2
:           bit CIA_PRB                                              ; 4 - sync: wait for ATN high
            bpl :-                                                   ; 3

sendloop:   ldx BLOCKBUFFER,y                                        ; 4
            lda SENDTABLELO,x                                        ; 4
:           bit CIA_PRB                                              ; 4 - sync: wait for ATN low
            bmi :-                                                   ; 3
            nop                                                      ; 2
            nop                                                      ; 2
            bit $24                                                  ; 3
            sta CIA_PRB                                              ; 4 - ATN is set low prior to reading
                                                                     ; = 71

            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            asl                                                      ; 2
            and #.lobyte(~ATNA_OUT)                                  ; 2
            sta CIA_PRB                                              ; 4
                                                                     ; = 16

            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            lda SENDTABLEHI,x                                        ; 4
            sta CIA_PRB                                              ; 4
                                                                     ; = 16

            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            asl                                                      ; 2
            and #.lobyte(~ATNA_OUT)                                  ; 2
            sta CIA_PRB                                              ; 4
                                                                     ; = 16

            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
            lda #DATA_OUT                                            ; 2
            sta CIA_PRB                                              ; 4
    .if DISABLE_WATCHDOG
            nop                                                      ; 2
            nop                                                      ; 2
            nop                                                      ; 2
    .else
cmdfdfix3 = * + 1
            lda #COUNT_TA_UNDF | FORCE_LOAD | ONE_SHOT | TIMER_START ; is changed to VIA access for FD
cmdfdfix4 = * + 1
            sta CIA_CRB                                              ; 2 + 4 - reset watchdog time-out
    .endif
            ldx #CLK_OUT                                             ; 2
blocksize:  cpy #$00                                                 ; 2
            iny                                                      ; 2
            bit CIA_PRB                                              ; 4
            bpl resend                                               ; 2
            bcc sendloop                                             ; 3
                                                                     ; = 119

.else; ::PROTOCOL != PROTOCOLS::TWO_BITS_RESEND

            ldy #$00
sendloop:
    .if !DISABLE_WATCHDOG
cmdfdfix3 = * + 1
            lda #COUNT_TA_UNDF | FORCE_LOAD | ONE_SHOT | TIMER_START ; is changed to VIA access for FD
cmdfdfix4 = * + 1
            sta CIA_CRB                                              ; 2 + 4 - reset watchdog time-out
    .endif
            ldx BLOCKBUFFER,y                                        ; 4
            lda SENDTABLELO,x                                        ; 4
                                                                     ; = 22 (+6 with watchdog)

:           bit CIA_PRB                                              ; 4
            bmi :-                                                   ; 3
            sta CIA_PRB                                              ; 4
            asl                                                      ; 2
            and #.lobyte(~ATNA_OUT)                                  ; 2
                                                                     ; = 15

:           bit CIA_PRB                                              ; 4
            bpl :-                                                   ; 3
            sta CIA_PRB                                              ; 4
            ldx BLOCKBUFFER,y                                        ; 4
            lda SENDTABLEHI,x                                        ; 4
                                                                     ; = 19

:           bit CIA_PRB                                              ; 4
            bmi :-                                                   ; 3
            sta CIA_PRB                                              ; 4
            asl                                                      ; 2
            and #.lobyte(~ATNA_OUT)                                  ; 2
blocksize:  cpy #$00                                                 ; 2
            iny                                                      ; 2
                                                                     ; = 19

:           bit CIA_PRB                                              ; 4
            bpl :-                                                   ; 3
            sta CIA_PRB                                              ; 4
            bcc sendloop                                             ; 3
                                                                     ; = 75

.endif; ::PROTOCOL != PROTOCOLS::TWO_BITS_RESEND

:           bit CIA_PRB; wait for acknowledgement
            bmi :-     ; of the last data byte

            lda LINKTRACK
            cmp JOBTRKSCTTABLE + (2 * BUFFERINDEX) + TRACKOFFSET
            beq drivebusy81; pull DATA_OUT high when changing tracks
drwaitrkch: ldy #CLK_OUT | DATA_OUT; flag track change
            SKIPWORD

            ; following code is transferred using KERNAL routines, then it is
            ; run and gets the rest of the code

drivebusy81:
            ldy #CLK_OUT
            sty CIA_PRB
            sei; disable watchdog
            rts

            ; must not trash x
dgetbyte:   lda #%10000000; CLK OUT lo: drive is ready
            sta BUFFER
            sta CIA_PRB
:           lda #CLK_IN
:           bit CIA_PRB
            beq :-
            lda CIA_PRB
            lsr
            ror BUFFER
            lda #CLK_IN
:           bit CIA_PRB
            bne :-
            lda CIA_PRB
            lsr
            ror BUFFER
            bcc :---
            lda BUFFER
            rts

DRVCODE81END = *
.export DRVCODE81END

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (!LOAD_ONCE) & (!UNINSTALL_RUNS_DINSTALL)
    DIRBUFFSIZE      = (BLOCKBUFFER - *) / 4
    DIRTRACKS        = *
    DIRSECTORS       = DIRTRACKS + DIRBUFFSIZE
    FILENAMEHASHVAL0 = DIRSECTORS + DIRBUFFSIZE
    FILENAMEHASHVAL1 = FILENAMEHASHVAL0 + DIRBUFFSIZE
    DIRBUFFEND       = FILENAMEHASHVAL1 + DIRBUFFSIZE

            .assert DIRBUFFSIZE >= 9, error, "***** Dir buffer too small. *****"

    DIRBUFFSIZE81 = DIRBUFFSIZE
    .export DIRBUFFSIZE81
.endif

.if !UNINSTALL_RUNS_DINSTALL
            .assert * <= BLOCKBUFFER, error, "***** 1581 drive code too large. *****"
.endif
            ; entry point

dinstall:   jsr drivebusy81; does sei, also signal to the computer
                           ; that the custom drive code has taken over

:           lda CIA_PRB; wait for DATA IN = high
            lsr
instalwait: bcc :-
            ldx #.lobyte(drvcodebeg81 - $01)
dgetrout:   inx
            bne :+
            inc dgetputhi
:           jsr dgetbyte
dgetputhi = * + $02
            sta a:.hibyte(drvcodebeg81 - $01) << 8,x
            cpx #.lobyte(drivebusy81 - $01)
            bne dgetrout
            dec drvcodebeg81
            bne dgetrout
            jmp dcodinit

.if (::FILESYSTEM = FILESYSTEMS::DIRECTORY_NAME) & (LOAD_ONCE = 0) & (UNINSTALL_RUNS_DINSTALL)
    DIRBUFFSIZE      = (BLOCKBUFFER - *) / 4
    DIRTRACKS        = *
    DIRSECTORS       = DIRTRACKS + DIRBUFFSIZE
    FILENAMEHASHVAL0 = DIRSECTORS + DIRBUFFSIZE
    FILENAMEHASHVAL1 = FILENAMEHASHVAL0 + DIRBUFFSIZE
    DIRBUFFEND       = FILENAMEHASHVAL1 + DIRBUFFSIZE

            .assert DIRBUFFSIZE >= 9, error, "***** Dir buffer too small. *****"

    DIRBUFFSIZE81 = DIRBUFFSIZE
    .export DIRBUFFSIZE81
.endif

.if UNINSTALL_RUNS_DINSTALL
            .assert * <= BLOCKBUFFER, error, "***** 1581 drive code too large. *****"
.endif

drvprgend81:
            .reloc
