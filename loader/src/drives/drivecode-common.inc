
.ifndef ::_DRIVECODE_COMMON_INC_
::_DRIVECODE_COMMON_INC_ = 1

; DIRCYCLEFLAG initial values
; will be increased by 1 on cycle complete
::NEW_DISK_VALUE  = $ff; upon reading the disk's directory for the first time,
                       ; it will wrap to $00 when the cycle is complete:
                       ; the dir buffer then holds the entire directory
::LOAD_FILE_VALUE = $7f; upon reading the disk's directory subsequent times,
                       ; it will wrap to $80 when the cycle is complete:
                       ; the dir buffer then holds only part of the directory
; on file not found, only cycle if DIRCYCLEFLAG is not $00 or $80
               
.macro GET_FILENAME drivetype
            ldx #LOAD_FILE_VALUE; $7f
            lda DIRCYCLEFLAG; if #files_in_dir < dirbuffsize (DIRCYCLEFLAG = $00),
            beq getfilenam  ; don't reset DIRCYCLEFLAG to $7f: do not cycle on file not found
            stx DIRCYCLEFLAG
getfilenam: jsr dgetbyte; get filename
            beq :+
            inx
    .if (.not .xmatch (drivetype, 1581))
            sta <(FILENAME - LOAD_FILE_VALUE - 1),x
    .else; 1581
            sta filename - LOAD_FILE_VALUE - 1,x
    .endif; 1581
            cpx #<(FILENAME_MAXLENGTH - 2 - LOAD_FILE_VALUE)
            bne getfilenam
:           jsr drwaitrkch; disables watchdog, does not change x
            txa             ; if zero-length filename,
            bpl loadnextfile; use hash values of next file
            jsr gethashval
            sta FILENAMEHASH1
            stx FILENAMEHASH0
loadnextfile:
.endmacro; GET_FILENAME drivetype


; matches against hash of filename in FILENAMEHASH0/1,
; sets a to file track and y to file sector

.macro FIND_FILE drivetype
    .if (.not .xmatch (drivetype, 1581))

            lda DISKCHANGED
            beq samedisk
        
newdisk:    ; a new disk has been inserted
            lda #DIRTRACK
            ldy #DIRSECTOR
            jsr getblkstid; store id, sector link sanity check
            bcs newdisk

           ;lda LINKTRACK
           ;ldy LINKSECTOR
            sty CYCLESTARTENDSECTOR

    .else; 1581

            lda NUMFILES
            beq newdisk
            lda CIA_PRA; query DISK_CHANGE
            bpl newdisk
            jmp samedisk

newdisk:    ; a new disk has been inserted
            jsr getdirtrk
            ldy #DIRSECTOR81
            jsr getblock
            bcs newdisk
  
           ;lda LINKTRACK
            sta CYCLESTARTENDTRACK
           ;ldy LINKSECTOR
            sty FIRSTDIRSECTOR
            sty CYCLESTARTENDSECTOR

    .endif; 1581
    
            ; nextdirseg -
            ; directory cycling: fill the dir buffer,
            ; this is also executed upon file not found in
            ; the currently buffered directory segment
            ; (with y containing NEXTDIRBLOCKSECTOR's value)

            ldx #NEW_DISK_VALUE ; $ff
            SKIPWORD
nextdirseg: ldx #LOAD_FILE_VALUE; $7f
            stx DIRCYCLEFLAG
            ldx #$00
            stx WRAPFILEINDEX
            stx NUMFILES
nextdirsct:

    .if (.not .xmatch (drivetype, 1581))
            lda #DIRTRACK
            ; y contains the current dir sector number
            jsr getblkchid; compare id, sector link sanity check
    .else; 1581
            ; a contains the current dir track number
            ; y contains the current dir sector number
            sta CURRDIRBLOCKTRACK
            jsr getblock
    .endif; 1581
            bcs newdisk; start over on error

           ;ldx CURRSECTOR
            stx CURRDIRBLOCKSECTOR
           ;ldy LINKSECTOR
           ;lda LINKTRACK
            bne :+
            ; wrap around to first dir block

    .if (.not .xmatch (drivetype, 1581))
            ldy #DIRSECTOR + 1
:           sty NEXTDIRBLOCKSECTOR
    .else; 1581
            jsr getdirtrk
            ldy FIRSTDIRSECTOR
:           sta NEXTDIRBLOCKTRACK
            sty NEXTDIRBLOCKSECTOR
    .endif; 1581

            ldy #$03
getdirloop: 
    .if (.xmatch (drivetype, 1541))
           ;ldx NUMFILES
            jsr gcrdecode; get file's start track
            sta DIRTRACKS,x
            tax          ; skip non-files
            beq dnotafile; denoted by track 0
            jsr gcrdecode; get file's start sector
            sta DIRSECTORS,x

    .elseif (.xmatch (drivetype, 1571))
            ldx NUMFILES
            lda BLOCKBUFFER + TRACKOFFSET,y; get file's start track
            sta .lobyte(DIRTRACKS),x
            beq dnotafile; skip non-files denoted by track 0
            lda BLOCKBUFFER + SECTOROFFSET,y; get file's start sector
            sta .lobyte(DIRSECTORS),x    
    .else; 1581
            ldx NUMFILES
            lda BLOCKBUFFER + TRACKOFFSET,y; get file's start track
            sta DIRTRACKS,x
            beq dnotafile; skip non-files denoted by track 0
            lda BLOCKBUFFER + SECTOROFFSET,y; get file's start sector
            sta DIRSECTORS,x
    .endif; 1581
    
            jsr fnamehash
            pha
            txa
            ldx NUMFILES; x is trashed in fnamehash
            sta FILENAMEHASHVAL0,x
            pla
            sta FILENAMEHASHVAL1,x

            ; advance to next file or quit loop
            inc NUMFILES
            cpx #DIRBUFFSIZE - 1
    .if (.not .xmatch (drivetype, 1581))
            lda CURRDIRBLOCKSECTOR
    .endif; not 1581
            bcs dirbuffull
            
            ; when starting to cycle through the directory, the files in
            ; the dir block the last file currently in the dir buffer is
            ; in, will all be added to the buffer when it will be filled
            ; on the subsequent file load - this required for correct
            ; load-next-file operation across buffer boundaries, and also
            ; the reason why the minimum dir buffer size is 9 files
dnotafile:  tya
            and #%11100000; 8 entries per block, $20 bytes per entry
           ;clc
            adc #$23
            tay
            bcc getdirloop; process all entries in a dir block

            ; process next dir block
            ldy NEXTDIRBLOCKSECTOR; y is getblk sector argument
    .if (.not .xmatch (drivetype, 1581))
            cpy #DIRSECTOR + 1
    .else; 1581
            jsr getdirtrk
            cmp NEXTDIRBLOCKTRACK
            bne :+
            cpy #DIRSECTOR81
    .endif; 1581
            bne :+
            lda NUMFILES
            sta WRAPFILEINDEX
:           
    .if (.xmatch (drivetype, 1581))
            lda NEXTDIRBLOCKTRACK
            cmp CYCLESTARTENDTRACK
            bne nextdirsct
    .endif; 1581
            cpy CYCLESTARTENDSECTOR
            bne nextdirsct
            
            ; cycle complete
            inc DIRCYCLEFLAG; $ff->$00 or $7f->$80, lsr:bc?
    .if (.not .xmatch (drivetype, 1581))
            SKIPWORD
dirbuffull: sta NEXTDIRBLOCKSECTOR
    .else; 1581
            bcs buffilled; jmp
dirbuffull: lda CURRDIRBLOCKTRACK
            sta NEXTDIRBLOCKTRACK
            lda CURRDIRBLOCKSECTOR
            sta NEXTDIRBLOCKSECTOR
    .endif; 1581

buffilled:  lda NUMFILES     ; if the dir does not wrap at the end of
            cmp WRAPFILEINDEX; the buffered entries, ignore the last
            beq samedisk     ; entry, so the dir is cycled when the
            dec NUMFILES     ; load-next-file file is the last entry

            ; the disk was not changed, or the dir has just been read
samedisk:   
    .if (.not .xmatch (drivetype, 1581))
            lda #$00; clear new disk flag
            sta DISKCHANGED
    .endif; !1581
            ldx NUMFILES
nextfile:   dex
    .if (.xmatch (drivetype, 1581))
            .assert DIRBUFFSIZE > $80, error, "***** Missed optimization opportunity. *****"
            cpx #$ff; DIRBUFFSIZE is bigger than $80
            bne findfile; check all dir entries in the buffer
    .else
            .assert DIRBUFFSIZE <= $80, error, "***** Invalid optimization. *****"
            bpl findfile; check all dir entries in the buffer
    .endif

            ; the dir buffer does not contain the file,
            ; so cycle through the directory to find it

            lda DIRCYCLEFLAG; cycle until the
            lsr             ; cycle is
    .if (.not .xmatch (drivetype, 1581))
            ldy NEXTDIRBLOCKSECTOR
            bcs nextdirseg  ; complete
    .else; !1581
            bcc :+
            lda NEXTDIRBLOCKTRACK
            ldy NEXTDIRBLOCKSECTOR
            jmp nextdirseg  ; complete
:
    .endif; !1581

            sec
            jmp filenotfnd

findfile:   lda FILENAMEHASH0
            eor FILENAMEHASHVAL0,x
            bne nextfile
            lda FILENAMEHASH1
            eor FILENAMEHASHVAL1,x
            bne nextfile

            ; file found

            stx FILEINDEX; store index of file to jump to the track of the file
                         ; following this one in the dir, after loading

            ; store number of the dir block loaded last,
            ; it is used to start the dir check cycle if
            ; the next file is not found in the dir buffer;
            ; it is also checked on the subsequent load to determine if the
            ; dir check cycle is complete and the file be said to be not found

    .if (.xmatch (drivetype, 1581))
            lda CURRDIRBLOCKTRACK
            sta CYCLESTARTENDTRACK
            sta NEXTDIRBLOCKTRACK
    .endif; 1581
            lda CURRDIRBLOCKSECTOR
            sta CYCLESTARTENDSECTOR
            sta NEXTDIRBLOCKSECTOR

    .if (.xmatch (drivetype, 1541))
            jsr busyledon; passes errorretlo, returns with carry set
                         ; (load first block in order to determine
                         ; the file's load address)
            lda DIRTRACKS,x
            ldy DIRSECTORS,x

            ; there should be a check for illegal track or sector
            ; here - unfortunately, there is no memory left for it

    .elseif (.xmatch (drivetype, 1571))
            jsr busyledon

            ; check for illegal track or sector
            ldy .lobyte(DIRTRACKS),x
            beq toillegal + $00
            cpy MAXTRACK
            bcs toillegal + $01
            jsr getnumscts
            stx NUMSECTORSTEMP
            ldx FILEINDEX
            lda .lobyte(DIRTRACKS),x
            ldy .lobyte(DIRSECTORS),x
            cpy NUMSECTORSTEMP
            bcc :+
toillegal:  sec
            jmp illegalts
:
            sec; load first block in order as to determine
               ; the file's load address
    .else; 1581
            lda DIRTRACKS,x
            ldy DIRSECTORS,x
    .endif; 1581
.endmacro; FIND_FILE drivetype


.macro PREPARE_NEXT_FILE drivetype
            ldx FILEINDEX
            inx
            lda FILENAMEHASHVAL0,x; store hash of next file's name, if
            sta FILENAMEHASH0     ; this is the last entry in the dir
            lda FILENAMEHASHVAL1,x; buffer, it will not be found, and
            sta FILENAMEHASH1     ; the dir is cycled through the buffer
    .if (.not .xmatch (drivetype, 1571))
            lda DIRTRACKS,x
    .else; 1571
            lda .lobyte(DIRTRACKS),x    
    .endif; 1571
            cpx WRAPFILEINDEX
            beq :+
            cpx NUMFILES
            bcc :++
:
    .if (.not .xmatch (drivetype, 1581))
            lda #DIRTRACK
    .else; 1581
            jsr getdirtrk
    .endif; 1581
:           jsr trackseek; move head to the start track of the next file in the directory
.endmacro; PREPARE_NEXT_FILE drivetype


.macro FNAMEHASH drivetype
            ; must not change y
fnamehash:  ldx #.lobyte(-$01 - LOAD_FILE_VALUE - 1)
:
    .if (.xmatch (drivetype, 1541))
            stx GCRBUFFER + $00
            jsr gcrdecode
            ldx GCRBUFFER + $00
    .else; 1571 | 1581
            lda BLOCKBUFFER + $02,y
            iny
    .endif; 1571 | 1581
            cmp #' ' | $80; $a0 = end of filename
            beq gethashval
            inx
    .if (.not .xmatch (drivetype, 1581))
            sta .lobyte(FILENAME - LOAD_FILE_VALUE - 1),x
    .else; 1581
            sta filename - LOAD_FILE_VALUE - 1,x
    .endif; 1581
            cpx #.lobyte(FILENAME_MAXLENGTH - 2 - LOAD_FILE_VALUE)
            bne :-

            ; must not change y
            ; x = length of filename + LOAD_FILE_VALUE + 1
gethashval: clc
            stx HASHVALUE0LO
            stx HASHVALUE0HI
            stx HASHVALUE1LO
            stx HASHVALUE1HI
hashloop:   
    .if (.not .xmatch (drivetype, 1581))
            lda .lobyte(FILENAME - LOAD_FILE_VALUE - 1),x
    .else; 1581
            lda filename - LOAD_FILE_VALUE - 1,x
    .endif; 1581
            adc HASHVALUE0LO
            sta HASHVALUE0LO
            bcc :+
            inc HASHVALUE0HI
           ;clc; saved for size reasons            
:           adc HASHVALUE1LO
            sta HASHVALUE1LO
            lda HASHVALUE0HI
            adc HASHVALUE1HI
            sta HASHVALUE1HI
            dex
            bmi hashloop
            adc HASHVALUE1LO
            tax
            lda HASHVALUE0LO
            adc HASHVALUE0HI
            rts
.endmacro; FNAMEHASH drivetype

.endif; !::_DRIVECODE_COMMON_INC_
