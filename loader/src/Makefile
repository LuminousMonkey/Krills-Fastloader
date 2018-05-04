
SOMAJOR      = 0
SOMINOR      = 0


ifeq ($(PLATFORM),)
_PLATFORM_   = c64
else ifeq ($(PLATFORM),c116)
_PLATFORM_   = c16
else ifeq ($(PLATFORM),plus4)
_PLATFORM_   = c16
else
_PLATFORM_   = $(PLATFORM)
endif

ifneq ($(_PLATFORM_),c64)
ifneq ($(_PLATFORM_),c16)
$(error invalid platform $(_PLATFORM_) specified)
endif
endif


TOP         ?= .

SVNVERSION   = svnversion
ifneq ($(wildcard ../../.svn/format),)
VERSION      = $(shell $(SVNVERSION) | tr -d [:cntrl:])
else
VERSION      =
endif

CD           = cd
ECHO         = echo
PRINTF       = printf
CAT          = cat
CP           = cp
MV           = mv
RM           = rm -f
MKDIR        = mkdir
RMDIR        = rmdir
TOUCH        = touch

AS           = ca65
LD           = ld65
AR           = ar65
VICE         = x64
C1541        = c1541

PU           = pucrunch
EXO          = exomizer

PERL         = perl
ZIP          = zip -9

INCDIR       = $(TOP)/../../shared
LDRINC       = $(TOP)/../include

DECOMPDIR    = $(TOP)/decompress
DRIVESDIR    = $(TOP)/drives
HALDIR       = $(TOP)/hal
INSTALLDIR   = $(TOP)/install
RESIDENTDIR  = $(TOP)/resident

BUILDDIR     = $(TOP)/../build
INTERMDIR    = $(TOP)/../build/interm

ifneq ($(EXTCONFIGPATH),)
CONFIG       = $(EXTCONFIGPATH)/loaderconfig.inc
else
CONFIG       = $(LDRINC)/config.inc
endif

INSTALLDEPS  = $(CONFIG) $(BUILDDIR) $(INTERMDIR) \
               $(INTERMDIR)/symbols1541-kernel-loadfile.inc $(INTERMDIR)/kernelsymbols1541.inc \
               $(DRIVESDIR)/drivecode-common.inc \
               $(DRIVESDIR)/drivecode1541-kernel.inc $(DRIVESDIR)/drivecode1541.s $(DRIVESDIR)/drivecode1541-loadfile.s $(DRIVESDIR)/drivecode1571.s $(DRIVESDIR)/drivecode1581.s \
               $(HALDIR)/hal.inc $(HALDIR)/hal-c64.inc $(HALDIR)/hal-c16.inc \
               $(INSTALLDIR)/install.s \
               $(LDRINC)/loader.inc $(LDRINC)/option-check.inc $(LDRINC)/common-features.inc $(LDRINC)/resident-jumptable.inc $(LDRINC)/install-jumptable.inc $(LDRINC)/diskio.inc \
               $(TOP)/../version.inc Makefile

RESIDENTDEPS = $(CONFIG) $(BUILDDIR) $(INTERMDIR) \
               $(DECOMPDIR)/exodecomp.s $(DECOMPDIR)/pudecomp.s $(DECOMPDIR)/doynaxdecomp.s $(DECOMPDIR)/bbdecomp.s $(DECOMPDIR)/lcdecomp.s \
               $(HALDIR)/hal.inc $(HALDIR)/hal-c64.inc $(HALDIR)/hal-c16.inc \
               $(RESIDENTDIR)/resident.s $(RESIDENTDIR)/decompress.s \
               $(LDRINC)/loader.inc $(LDRINC)/option-check.inc $(LDRINC)/common-features.inc $(LDRINC)/resident-jumptable.inc $(LDRINC)/install-jumptable.inc $(LDRINC)/diskio.inc \
               $(TOP)/../version.inc Makefile

BINDEPS      = $(BUILDDIR)/loadersymbols-$(_PLATFORM_).inc $(BUILDDIR)/loader-$(_PLATFORM_).prg $(CONFIG)


ifeq ($(_PLATFORM_),c16)
AS_FLAGS    += -t c16 -D PLATFORM=16
else
AS_FLAGS    += -t c64 -D PLATFORM=64
endif
AS_FLAGS    += -I $(TOP)/. -I $(INCDIR) -I $(LDRINC)
ifneq ($(EXTCONFIGPATH),)
AS_FLAGS    += -D EXTCONFIGPATH -I $(EXTCONFIGPATH)
endif
ifneq ($(DEBUG),)
AS_FLAGS    += -g
endif


default: lib

all: lib prg

# use these targets to build loader.prg and install.prg
prg bin binary: $(BINDEPS)

prgzip binzip binaryzip: $(BUILDDIR)/loader-$(_PLATFORM_).zip


lib: lib-basic # lib-full for dynlink stuff
so: so-basic # so-full for dynlink stuff
dll: so

mods: drivecode1541-loadfile.prg


../../.svn/entries:
ifeq ($(VERSION),)
	$(MKDIR) ../../.svn
	$(TOUCH) $@
endif

$(TOP)/../version.inc: ../../.svn/entries
	$(MAKE) -C $(TOP)/.. version.inc


# directory targets

$(BUILDDIR):
	$(MKDIR) $(BUILDDIR)

$(INTERMDIR):
	$(MKDIR) $(INTERMDIR)


# object targets

$(INTERMDIR)/zp-resident.o: $(CONFIG) $(BUILDDIR) $(INTERMDIR) $(LDRINC)/option-check.inc $(RESIDENTDIR)/zp-resident.s
	$(AS) $(AS_FLAGS) -o $@ $(RESIDENTDIR)/zp-resident.s

$(INTERMDIR)/loader-$(_PLATFORM_).o: $(RESIDENTDEPS)
	$(AS) $(AS_FLAGS) -o $@ $(RESIDENTDIR)/resident.s

$(INTERMDIR)/install-$(_PLATFORM_).o: $(INSTALLDEPS)
	$(AS) $(AS_FLAGS) --cpu 6502X -I $(INTERMDIR) -o $@ $(INSTALLDIR)/install.s
	# --cpu 6502X for illegal opcodes


# binary targets
 # drive-side binaries
 
 # 1541 kernel with loadfile module
 # this is mainly needed to resolve circular symbol dependencies between kernel and loadfile module
$(INTERMDIR)/symbols1541-kernel-loadfile.inc: $(INTERMDIR)/drivecode1541-kernel-loadfile.prg.map
	$(PERL) $(TOP)/drives/make-kernelsymbolsinc.pl $^ > $@

$(INTERMDIR)/drivecode1541-kernel-loadfile.link: Makefile
	$(PRINTF) "MEMORY \n{\n DRIVERAM: start = \$$00, size = \$$0800, file = \"$(INTERMDIR)/drivecode1541-kernel-loadfile.prg\";\n}\n\nSEGMENTS\n{\n CODE: load = DRIVERAM;\n}" > $@

$(INTERMDIR)/drivecode1541-kernel-loadfile.o: $(DRIVESDIR)/drivecode1541.s $(DRIVESDIR)/drivecode1541-loadfile.s $(CONFIG)
	$(AS) --cpu 6502X $(AS_FLAGS) -D BUILD_KERNEL=1 -D LOADFILE=1 -o $@ $<
	# --cpu 6502X for illegal op-codes

$(INTERMDIR)/drivecode1541-kernel-loadfile.prg $(INTERMDIR)/drivecode1541-kernel-loadfile.prg.map: $(INTERMDIR)/drivecode1541-kernel-loadfile.o $(INTERMDIR)/drivecode1541-kernel-loadfile.link
	$(LD) -o $(INTERMDIR)/drivecode1541-kernel-loadfile.prg -C $(INTERMDIR)/drivecode1541-kernel-loadfile.link $(INTERMDIR)/drivecode1541-kernel-loadfile.o -vm -m $(INTERMDIR)/drivecode1541-kernel-loadfile.prg.map
	$(RM) a.out

drivecode1541-kernel-loadfile.prg: $(INTERMDIR)/drivecode1541-kernel-loadfile.prg
 
 # 1541 kernel
$(INTERMDIR)/drivecode1541-kernel.link: Makefile
	$(PRINTF) "MEMORY \n{\n DRIVERAM: start = \$$00, size = \$$0800, file = \"$(INTERMDIR)/drivecode1541-kernel.prg\";\n}\n\nSEGMENTS\n{\n CODE: load = DRIVERAM;\n}" > $@

$(INTERMDIR)/drivecode1541-kernel.o: $(DRIVESDIR)/drivecode1541.s $(INTERMDIR)/symbols1541-kernel-loadfile.inc $(CONFIG)
	$(AS) --cpu 6502X $(AS_FLAGS) -I $(INTERMDIR) -D BUILD_KERNEL=1 -o $@ $<
	# --cpu 6502X for illegal op-codes

$(INTERMDIR)/drivecode1541-kernel.prg $(INTERMDIR)/drivecode1541-kernel.prg.map: $(INTERMDIR)/drivecode1541-kernel.o $(INTERMDIR)/drivecode1541-kernel.link
	$(LD) -o $(INTERMDIR)/drivecode1541-kernel.prg -C $(INTERMDIR)/drivecode1541-kernel.link $(INTERMDIR)/drivecode1541-kernel.o -vm -m $(INTERMDIR)/drivecode1541-kernel.prg.map
	$(RM) a.out

drivecode1541-kernel.prg: $(INTERMDIR)/drivecode1541-kernel.prg

 # 1541 loadfile module
$(INTERMDIR)/kernelsymbols1541.inc: $(INTERMDIR)/drivecode1541-kernel.prg.map
	$(PERL) $(TOP)/drives/make-kernelsymbolsinc.pl $^ > $@

$(INTERMDIR)/drivecode1541-loadfile.link: Makefile
	$(PRINTF) "MEMORY \n{\n DRIVERAM: start = \$$00, size = \$$0800, file = \"../build/drivecode1541-loadfile.prg\";\n}\n\nSEGMENTS\n{\n CODE: load = DRIVERAM;\n}" > $@

$(INTERMDIR)/drivecode1541-loadfile.o: $(DRIVESDIR)/drivecode1541-loadfile.s $(INTERMDIR)/kernelsymbols1541.inc $(DRIVESDIR)/drivecode1541-kernel.inc $(DRIVESDIR)/drivecode-common.inc
	$(AS) --cpu 6502X $(AS_FLAGS) -I $(INTERMDIR) -D MODULE=1 -o $@ $(DRIVESDIR)/drivecode1541-loadfile.s
	# --cpu 6502X for illegal op-codes

$(BUILDDIR)/drivecode1541-loadfile.prg $(BUILDDIR)/drivecode1541-loadfile.prg.map: $(INTERMDIR)/drivecode1541-loadfile.o $(INTERMDIR)/drivecode1541-loadfile.link
	$(LD) -o $(BUILDDIR)/drivecode1541-loadfile.prg -C $(INTERMDIR)/drivecode1541-loadfile.link $< -vm -m $(INTERMDIR)/drivecode1541-loadfile.prg.map
	$(RM) a.out

drivecode1541-loadfile.prg: $(BUILDDIR)/drivecode1541-loadfile.prg


 # host-side binaries
.PHONY: $(INTERMDIR)/binary.link $(BUILDDIR)/loader.prg $(INTERMDIR)/install-nonreloc-$(_PLATFORM_).o $(BUILDDIR)/install.prg $(INTERMDIR)/loader-nonreloc-$(_PLATFORM_).o $(INTERMDIR)/loader.map (BUILDDIR)/loadersymbols.inc

$(INTERMDIR)/loader-nonreloc-$(_PLATFORM_).o: $(RESIDENTDEPS)
ifeq ($(RESIDENT),)
	@$(ECHO) "Usage: $(MAKE) prg INSTALL=<install hexaddress> RESIDENT=<resident hexaddress> ZP=<zp hexaddress>"
	@exit -1
endif
	$(AS) $(AS_FLAGS) -D RESIADDR=0x$(RESIDENT) -o $@ $(RESIDENTDIR)/resident.s

$(INTERMDIR)/install-nonreloc-$(_PLATFORM_).o: $(RESIDENTDEPS)
ifeq ($(INSTALL),)
	@$(ECHO) "Usage: $(MAKE) prg INSTALL=<install hexaddress> RESIDENT=<resident hexaddress> ZP=<zp hexaddress>"
	@exit -1
endif
	$(AS) $(AS_FLAGS) -D INSTADDR=0x$(INSTALL) --cpu 6502X -o $@ $(INSTALLDIR)/install.s
	# --cpu 6502X for illegal opcodes

$(INTERMDIR)/binary.link: Makefile
ifeq ($(ZP),)
	@$(ECHO) "Usage: $(MAKE) prg INSTALL=<install hexaddress> RESIDENT=<resident hexaddress> ZP=<zp hexaddress>"
	@exit -1
endif
	$(PERL) -e 'printf "MEMORY\
	{\
	 ZPRAM: start = \$$$(ZP), size = \$$%x;\
	 INSTALLRAM: start = \$$%x, size = \$$%x, file = \"../build/install-$(_PLATFORM_).prg\";\
	 RESIDENTRAM: start = \$$%x, size = \$$%x, file = \"../build/loader-$(_PLATFORM_).prg\";\
	}\
	\
	SEGMENTS\
	{\
	 DISKIO_ZP: load = ZPRAM, type = zp;\
	 DISKIO: load = RESIDENTRAM;\
	 DISKIO_INSTALL: load = INSTALLRAM;\
	}", 0x0100 - 0x$(ZP), 0x$(INSTALL) - 2, 0x10002 - 0x$(INSTALL), 0x$(RESIDENT) - 2, 0x10002 - 0x$(RESIDENT)' > $@

$(BUILDDIR)/loader-$(_PLATFORM_).prg $(BUILDDIR)/install-$(_PLATFORM_).prg: $(INTERMDIR)/zp-resident.o $(INTERMDIR)/loader-nonreloc-$(_PLATFORM_).o $(INTERMDIR)/install-nonreloc-$(_PLATFORM_).o $(INTERMDIR)/binary.link
	$(LD) -C $(INTERMDIR)/binary.link -vm -m $(INTERMDIR)/loader-$(_PLATFORM_).map $(INTERMDIR)/zp-resident.o $(INTERMDIR)/loader-nonreloc-$(_PLATFORM_).o $(INTERMDIR)/install-nonreloc-$(_PLATFORM_).o
	$(RM) a.out

$(INTERMDIR)/loader-$(_PLATFORM_).map: $(BUILDDIR)/install-$(_PLATFORM_).prg

$(BUILDDIR)/loadersymbols-$(_PLATFORM_).inc: $(INTERMDIR)/loader-$(_PLATFORM_).map
	$(PERL) make-loadersymbolsinc.pl $^ > $@

$(BUILDDIR)/loader-$(_PLATFORM_).zip: $(BINDEPS)
	$(CD) $(BUILDDIR) \
	 && $(CP) $(BUILDDIR)/loader-$(_PLATFORM_).prg $(INTERMDIR)/loader.prg && $(ZIP) -j $@ $(INTERMDIR)/loader.prg \
	 && $(CP) $(BUILDDIR)/install-$(_PLATFORM_).prg $(INTERMDIR)/install.prg && $(ZIP) -j $@ $(INTERMDIR)/install.prg \
	 && $(CP) $(BUILDDIR)/loadersymbols-$(_PLATFORM_).inc $(INTERMDIR)/loadersymbols.inc && $(ZIP) -j $@ $(INTERMDIR)/loadersymbols.inc


# dynlink targets

$(INTERMDIR)/module.link: Makefile
	@$(PERL) -e 'printf "MEMORY {\
	ZP:       start = \$$0000, size = \$$0100, type = rw, define = yes;\
	COMBINED: start = \$$0000, size = \$$FFFF, file = %%O;\
	}\
	SEGMENTS {\
	JUMPTABLE: load = COMBINED, type = ro;\
	INIT:      load = COMBINED, type = ro,  optional = yes;\
	CODE:      load = COMBINED, type = ro;\
	RODATA:    load = COMBINED, type = ro;\
	DATA:      load = COMBINED, type = rw,  define = yes;\
	BSS:       load = COMBINED, type = bss, define = yes;\
	ZEROPAGE:  load = ZP,       type = zp;\
	EXTZP:     load = ZP,       type = zp;\
	}\
	FILES {\
	%%O: format = o65;\
	}\
	FORMATS {\
	o65: os = cc65, type = small\
;}#	   , id = \$$8000, import = PRINTHEX;}\
"' > $@

# uncomment the import line above to enable debug output code callable from the loader code in the dynlink library

$(INTERMDIR)/zp-resident.o65.o: $(CONFIG) $(LDRINC)/option-check.inc $(RESIDENTDIR)/zp-resident.s
	$(AS) $(AS_FLAGS) -D DYNLINK_EXPORT -o $@ $(RESIDENTDIR)/zp-resident.s

$(INTERMDIR)/loader-$(_PLATFORM_).o65.o: $(RESIDENTDEPS)
	$(AS) $(AS_FLAGS) -D DYNLINK_EXPORT -o $@ $(RESIDENTDIR)/resident.s

$(INTERMDIR)/install-$(_PLATFORM_).o65.o: $(INSTALLDEPS)
	$(AS) $(AS_FLAGS) -D DYNLINK_EXPORT --cpu 6502X -I $(INTERMDIR) -o $@ $(INSTALLDIR)/install.s
	# --cpu 6502X for illegal opcodes

$(INTERMDIR)/install-$(_PLATFORM_).o65: $(INTERMDIR)/install-$(_PLATFORM_).o65.o $(INTERMDIR)/zp-resident.o65.o
	$(LD) -o $@ -t module -vm -m $@.map $^

$(INTERMDIR)/loader-$(_PLATFORM_).o65: $(INTERMDIR)/module.link $(INTERMDIR)/loader-$(_PLATFORM_).o65.o $(INTERMDIR)/zp-resident.o65.o
	$(LD) -o $@ -C $^ # no map here because of a bug in ld65 when trying to print data for the external PRINTHEX label

$(BUILDDIR)/loader-$(_PLATFORM_).so: $(INTERMDIR)/loader-$(_PLATFORM_).so.uncompd Makefile
	$(EXO) raw -m 512 $(INTERMDIR)/loader-$(_PLATFORM_).so.uncompd -o $(INTERMDIR)/loader-$(_PLATFORM_).so.temp
	$(PRINTF) "\xC4ISK \xC9/\xCF \xCCIBRARY\x00\x$(SOMAJOR)\x$(SOMINOR)" | $(CAT) - $(INTERMDIR)/loader-$(_PLATFORM_).so.temp > $@

$(INTERMDIR)/loader-$(_PLATFORM_).so.uncompd: $(INTERMDIR)/install-$(_PLATFORM_).o65 $(INTERMDIR)/loader-$(_PLATFORM_).o65
	$(CAT) $^ > $@

.PHONY: CHECK_CC65_INC
CHECK_CC65_INC:
ifeq ($(CC65_INC),)
	$(error CC65_INC environment variable pointing to the CC65 include folder not set)
endif

.PHONY: CHECK_CC65_SRC
CHECK_CC65_SRC:
ifeq ($(CC65_SRC),)
	$(error CC65_SRC environment variable pointing to the CC65 source code folder not set)
endif

$(INTERMDIR)/dynlink-$(_PLATFORM_).o: $(INSTALLDIR)/dynlink.s CHECK_CC65_INC $(LDRINC)/diskio.inc $(BUILDDIR)/loader-$(_PLATFORM_).so
	$(AS) $(AS_FLAGS) -I $(CC65_INC) -o $*.o $<

$(INTERMDIR)/exostreamdecr1.o: $(DECOMPDIR)/exostreamdecr1.s
	$(AS) $(AS_FLAGS) -o $@ $?

$(INTERMDIR)/modload.o: CHECK_CC65_INC CHECK_CC65_SRC $(CC65_SRC)/libsrc/common/modload.s
	$(AS) $(AS_FLAGS) -I $(CC65_INC)/../asminc -o $@ $(CC65_INC)/../libsrc/common/modload.s

$(INTERMDIR)/memset.o: CHECK_CC65_INC CHECK_CC65_SRC $(CC65_SRC)/libsrc/common/memset.s
	$(AS) $(AS_FLAGS) -I $(CC65_INC)/../asminc -o $@ $(CC65_INC)/../libsrc/common/memset.s

$(INTERMDIR)/pushax.o: CHECK_CC65_INC CHECK_CC65_SRC $(CC65_SRC)/libsrc/runtime/pushax.s
	$(AS) $(AS_FLAGS) -I $(CC65_INC)/../asminc -o $@ $(CC65_INC)/../libsrc/runtime/pushax.s

$(INTERMDIR)/decax1.o: CHECK_CC65_INC CHECK_CC65_SRC $(CC65_SRC)/libsrc/runtime/decax1.s
	$(AS) $(AS_FLAGS) -I $(CC65_INC)/../asminc -o $@ $(CC65_INC)/../libsrc/runtime/decax1.s

$(INTERMDIR)/incsp2.o: CHECK_CC65_INC CHECK_CC65_SRC $(CC65_SRC)/libsrc/runtime/incsp2.s
	$(AS) $(AS_FLAGS) -I $(CC65_INC)/../asminc -o $@ $(CC65_INC)/../libsrc/runtime/incsp2.s


# loader-$(_PLATFORM_).a library target

$(BUILDDIR)/loader-$(_PLATFORM_).a: $(INTERMDIR)/zp-resident.o $(INTERMDIR)/loader-$(_PLATFORM_).o $(INTERMDIR)/install-$(_PLATFORM_).o
	$(AR) a $@ $^

lib-basic: $(BUILDDIR)/loader-$(_PLATFORM_).a

lib-full: so-full

so-basic: $(BUILDDIR)/loader-$(_PLATFORM_).a

so-full: $(BUILDDIR)/loader-$(_PLATFORM_).a $(INTERMDIR)/dynlink-$(_PLATFORM_).o $(INTERMDIR)/exostreamdecr1.o $(INTERMDIR)/modload.o $(INTERMDIR)/memset.o $(INTERMDIR)/pushax.o $(INTERMDIR)/decax1.o $(INTERMDIR)/incsp2.o
	$(AR) a $^


clean:
	-$(RM) \
	 $(INTERMDIR)/* \
	 $(BUILDDIR)/loader-$(_PLATFORM_).a $(BUILDDIR)/loader-$(_PLATFORM_).so \
	 $(BUILDDIR)/loader-$(_PLATFORM_).prg $(BUILDDIR)/install-$(_PLATFORM_).prg $(BUILDDIR)/loadersymbols-$(_PLATFORM_).inc
	-$(RMDIR) $(INTERMDIR)
