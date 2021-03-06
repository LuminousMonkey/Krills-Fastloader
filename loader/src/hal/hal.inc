
.ifndef _HAL_INC_
_HAL_INC_ = 1

.if PLATFORM = diskio::platform::COMMODORE_16
    .include "hal/hal-c16.inc"
.else; PLATFORM <> diskio::platform::COMMODORE_16
    .include "hal/hal-c64.inc"
.endif; PLATFORM <> diskio::platform::COMMODORE_16


.macro DO_UNINSTALL
    .if NONBLOCKING_API
            DISABLE_TIMER_IRQ
            ACK_TIMER_IRQ
    .endif
            SET_IO_KERNAL
    .if !UNINSTALL_RUNS_DINSTALL
:           BRANCH_IF_CLK_IN_OR_DATA_IN_CLEAR :-
    .else
:           BRANCH_IF_CLK_IN_CLEAR :-
    .endif
.endmacro

.macro BRANCH_IF_CHANGING_TRACK to
            BRANCH_IF_DATA_IN_CLEAR to
.endmacro

.macro BRANCH_IF_BLOCK_READY to
            BRANCH_IF_CLK_IN_SET to
.endmacro

.macro BRANCH_IF_BLOCK_NOT_READY to
            BRANCH_IF_CLK_IN_CLEAR to
.endmacro

.macro WAIT_FOR_BLOCK_READY
:           BRANCH_IF_BLOCK_NOT_READY :-
.endmacro

.macro WAIT_FOR_BLOCK_READY_KERNAL
:           BRANCH_IF_CLK_IN_CLEAR :-
.endmacro

.macro GETBYTE_SETUP
    .if PROTOCOL = PROTOCOLS::TWO_BITS_RESEND
            GETBYTE_TWO_BITS_RESEND_SETUP
    .else
            GETBYTE_TWO_BITS_ATN_SETUP
    .endif
.endmacro

.macro GETBYTE
    .if PROTOCOL = PROTOCOLS::TWO_BITS_RESEND
            GETBYTE_TWO_BITS_RESEND
    .else
            GETBYTE_TWO_BITS_ATN
    .endif
.endmacro

.endif; !_HAL_INC_
