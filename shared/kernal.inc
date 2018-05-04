
.ifndef _KERNAL_INC_
_KERNAL_INC_ = 1

DEVICE_SCREEN   = $03

INDEX1          = $22; utility pointer area
FRFTOP          = $33; pointer: bottom of string storage
FRESPC          = $35; utility string pointer
FACEXP          = $61; FAC exponent
FACHO           = $62; FAC mantissa
STRDSC          = $64; temporary string descriptor
 STRDSC_LEN      = 0
 STRDSC_PTR      = 1
FACSGN          = $66; FAC sign
STATUS          = $90
NUMOPENFILES    = $98

CINV            = $0314
CBINV           = $0316


.if .defined(PLATFORM) & (PLATFORM = 16)

DFLTO           = $99; default output device
FA              = $ae; current io device
USE4DY          = $f9

PALETTE         = $07f9
PALETTE_DEFAULT = $ff
PALETTE_USER    = $00

CLRSCR          = $d88b

IBASIN          = $0322; CHRIN vector
IBSOUT          = $0324; CHROUT vector

.else

.define KERNAL_ROM      $e000
.define KERNAL_ROM_SIZE $2000

.define ARG    $69
.define STATUS $90
.define DFLTO  $9a; default output device
.define FA     $ba; current io device
.define PNT    $d1
.define PNTR   $d3
.define LDTB1  $d9

.define COLOR  $0286

.define NMINV  $0318
.define IBASIN $0324; CHRIN vector
.define IBSOUT $0326; CHROUT vector


.define POLYX  $e059
.define CLRSCR $e544
.define ROWSLO $ecf0

.endif


.define LISTEN $ffb1
.define LSTNSA $ff93
 .define SA_TALK                      $20
 .define SA_UNTALK                    $3f
 .define SA_LISTEN                    $40
 .define SA_UNLISTEN                  $5f
 .define SA_OPENCHANNEL               $60
 .define SA_CLOSE                     $e0
 .define SA_OPEN                      $f0
.define TKSA   $ff96
.define IECIN  $ffa5
.define IECOUT $ffa8
.define UNTLK  $ffab
.define UNLSTN $ffae
.define TALK   $ffb4
.define READST $ffb7
 .define KERNAL_STATUS_EOF            %01000000
 .define KERNAL_STATUS_FILE_NOT_FOUND %00000010
.define SETLFS $ffba
 .define COMMAND_ERROR_CHANNEL $0f
.define SETNAM $ffbd
.define OPEN   $ffc0
 .define KERNAL_TOOMANYFILES          $01
 .define KERNAL_FILEOPEN              $02
 .define KERNAL_FILENOTOPEN           $03
 .define KERNAL_FILENOTFOUND          $04
 .define KERNAL_DEVICENOTPRESENT      $05
 .define KERNAL_NOTINPUTFILE          $06
 .define KERNAL_NOTOUTPUTFILE         $07
 .define KERNAL_MISSINGFILENAME       $08
 .define KERNAL_ILLEGALDEVICENUMBER   $09
.define CLOSE  $ffc3
.define CHKIN  $ffc6
.define CHKOUT $ffc9
.define CLRCHN $ffcc
.define CHRIN  $ffcf
.define CHROUT $ffd2
.define LOAD   $ffd5
.define SAVE   $ffd8


.endif; !_KERNAL_INC_
