
NOWORKINGCOPY      = $(shell svn info > /dev/null 2>&1; echo $$?)
SVNVERSION         = svnversion
ifeq ($(NOWORKINGCOPY),0)
VERSION            = $(shell $(SVNVERSION) | tr -d [:cntrl:])
else
VERSION            =
endif

CD                 = cd
PRINTF             = printf
MKDIR              = mkdir
TOUCH              = touch
ZIP                = zip -9
ZIP_NO_PATHS       = $(ZIP) -j
ifneq ($(VERSION),)
ZIPFILE            = loader-v$(VERSION).zip
LOADERTEST         = loadertest-v$(VERSION).zip
else
ZIPFILE            = loader.zip
LOADERTEST         = loadertest.zip
endif


SHAREDFOLDER       = shared
LOADERFOLDER       = $(notdir $(shell pwd))
DOCSFOLDER         = $(LOADERFOLDER)/docs
SRCFOLDER          = $(LOADERFOLDER)/src
INCFOLDER          = $(LOADERFOLDER)/include
SAMPLESFOLDER      = $(LOADERFOLDER)/samples
BUILDFOLDER        = $(LOADERFOLDER)/build
TOOLSFOLDER        = $(LOADERFOLDER)/tools


ZIPLIST           += $(SHAREDFOLDER)/standard.inc
ZIPLIST           += $(SHAREDFOLDER)/cpu.inc
ZIPLIST           += $(SHAREDFOLDER)/vic.inc
ZIPLIST           += $(SHAREDFOLDER)/cia.inc
ZIPLIST           += $(SHAREDFOLDER)/ted.inc
ZIPLIST           += $(SHAREDFOLDER)/via.inc
ZIPLIST           += $(SHAREDFOLDER)/kernal.inc
ZIPLIST           += $(SHAREDFOLDER)/basic.inc
ZIPLIST           += $(SHAREDFOLDER)/float.inc

ZIPLIST           += $(LOADERFOLDER)/Makefile
ZIPLIST           += $(LOADERFOLDER)/version.inc

ZIPLIST           += $(DOCSFOLDER)/FilenameHashFunction.txt
ZIPLIST           += $(DOCSFOLDER)/GCRTiming.txt
ZIPLIST           += $(DOCSFOLDER)/Prerequisites.txt
ZIPLIST           += $(DOCSFOLDER)/Protocols.txt
ZIPLIST           += $(DOCSFOLDER)/Thanks.txt
ZIPLIST           += $(DOCSFOLDER)/Usage.txt

DECOMPFOLDER       = decompress
DRIVESFOLDER       = drives
HALFOLDER          = hal
INSTALLFOLDER      = install
RESIDENTFOLDER     = resident
ZIPLIST           += $(SRCFOLDER)/Makefile
ZIPLIST           += $(SRCFOLDER)/make-loadersymbolsinc.pl
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/exostreamdecr1.s
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/exodecomp.s
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/pudecomp.s
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/doynaxdecomp.s
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/bbdecomp.s
ZIPLIST           += $(SRCFOLDER)/$(DECOMPFOLDER)/lcdecomp.s
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode-common.inc
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode1541-kernel.inc
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode1541.s
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode1541-loadfile.s
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode1571.s
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/drivecode1581.s
ZIPLIST           += $(SRCFOLDER)/$(DRIVESFOLDER)/make-kernelsymbolsinc.pl
ZIPLIST           += $(SRCFOLDER)/$(HALFOLDER)/hal.inc
ZIPLIST           += $(SRCFOLDER)/$(HALFOLDER)/hal-c64.inc
ZIPLIST           += $(SRCFOLDER)/$(HALFOLDER)/hal-c16.inc
ZIPLIST           += $(SRCFOLDER)/$(INSTALLFOLDER)/install.s
ZIPLIST           += $(SRCFOLDER)/$(INSTALLFOLDER)/dynlink.s
ZIPLIST           += $(SRCFOLDER)/$(RESIDENTFOLDER)/zp-resident.s
ZIPLIST           += $(SRCFOLDER)/$(RESIDENTFOLDER)/resident.s
ZIPLIST           += $(SRCFOLDER)/$(RESIDENTFOLDER)/decompress.s

ZIPLIST           += $(INCFOLDER)/config.inc
ZIPLIST           += $(INCFOLDER)/loader.inc
ZIPLIST           += $(INCFOLDER)/diskio.inc
ZIPLIST           += $(INCFOLDER)/option-check.inc
ZIPLIST           += $(INCFOLDER)/common-features.inc
ZIPLIST           += $(INCFOLDER)/install-jumptable.inc
ZIPLIST           += $(INCFOLDER)/resident-jumptable.inc

MINEXAMPLEFOLDER   = minexample
RESOURCESFOLDER    = resources
TESTFOLDER         = test
TURNDISKFOLDER     = turndisk
ZIPLIST           += $(SAMPLESFOLDER)/$(RESOURCESFOLDER)/sheba.bin
ZIPLIST           += $(SAMPLESFOLDER)/$(RESOURCESFOLDER)/prlogo.bin
ZIPLIST           += $(SAMPLESFOLDER)/$(MINEXAMPLEFOLDER)/Makefile
ZIPLIST           += $(SAMPLESFOLDER)/$(MINEXAMPLEFOLDER)/Linkfile
ZIPLIST           += $(SAMPLESFOLDER)/$(MINEXAMPLEFOLDER)/minexample.s
ZIPLIST           += $(SAMPLESFOLDER)/$(MINEXAMPLEFOLDER)/loaderconfig.inc
ZIPLIST           += $(SAMPLESFOLDER)/$(TESTFOLDER)/Makefile
ZIPLIST           += $(SAMPLESFOLDER)/$(TESTFOLDER)/Linkfile
ZIPLIST           += $(SAMPLESFOLDER)/$(TESTFOLDER)/test.s
ZIPLIST           += $(SAMPLESFOLDER)/$(TESTFOLDER)/zp.inc
ZIPLIST           += $(SAMPLESFOLDER)/$(TURNDISKFOLDER)/Makefile
ZIPLIST           += $(SAMPLESFOLDER)/$(TURNDISKFOLDER)/Linkfile
ZIPLIST           += $(SAMPLESFOLDER)/$(TURNDISKFOLDER)/turndisk.s
ZIPLIST           += $(SAMPLESFOLDER)/$(TURNDISKFOLDER)/loaderconfig.inc

CC1541SRCFOLDER    = cc1541_source
ZIPLIST           += $(TOOLSFOLDER)/compressedfileconverter.pl
ZIPLIST           += $(TOOLSFOLDER)/CRUSH.EXE
ZIPLIST           += $(TOOLSFOLDER)/cwsdpmi.exe
ZIPLIST           += $(TOOLSFOLDER)/$(CC1541SRCFOLDER)/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(CC1541SRCFOLDER)/cc1541.cpp
ZIPLIST           += $(TOOLSFOLDER)/$(CC1541SRCFOLDER)/filefinder.cpp
ZIPLIST           += $(TOOLSFOLDER)/$(CC1541SRCFOLDER)/XGetOpt.cpp
ZIPLIST           += $(TOOLSFOLDER)/$(CC1541SRCFOLDER)/XGetOpt.h

EXOFOLDER          = exomizer207
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/changelog.txt
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exo20info.txt
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exobasic10b2.txt
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/6502emu.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/6502emu.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/asm.tab.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/asm.tab.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/asm.y
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/asm.yy
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/b2membuf.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bas_main.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg_actions.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg_link_patch.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg_renumber.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg_trampoline.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/bprg.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/callback.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/chunkpool.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/chunkpool.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/common.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/desfx.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/desfx.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_helper.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_helper.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_main.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_raw.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_util.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exo_util.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exodec.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/exodec.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/expr.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/expr.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/getflag.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/getflag.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/int.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/lex.yy.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/log.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/log.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/map.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/map.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/match.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/match.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/membuf_io.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/membuf_io.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/membuf.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/membuf.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/named_buffer.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/named_buffer.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/optimal.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/optimal.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/output.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/output.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/parse.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/parse.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/pc.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/pc.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/progress.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/progress.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/radix.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/radix.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/search.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/search.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/vec.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/vec.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/src/sfxdecr.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/data.bin
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/data.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/dataf.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/exodecrunch.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/exostreamdecr1.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/exostreamdecr2.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/krilldecr.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/main.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/main1.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/main2.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/mainf.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/streamdata.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/testrun.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/dasm/exodecrunch.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/exodecrs/dasm/wrap.s
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/exodecr.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/exodecr.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/exodecrunch.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/exodecrunch.h
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/main.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/main2.c
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/test1.bin
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/test2.bin
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/test3.bin
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/6809/exo2_final.asm
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/6809/exo2_puls.txt
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/z80/deexo_b.asm
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/z80/deexo_simple.asm
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/z80/deexo_simple_b.asm
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/z80/deexo.asm
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/rawdecrs/z80/readme.txt
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/win32/exobasic.exe
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/win32/exomizer.exe
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/dos/exobasic.exe
ZIPLIST           += $(TOOLSFOLDER)/$(EXOFOLDER)/dos/exomizer.exe

PUFOLDER           = pucrunch
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/smakefile
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/pucrunch.c
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/pucrunch.h
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/uncrunch.asm
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/uncrunch-z80.asm
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/sa_uncrunch.asm
ZIPLIST           += $(TOOLSFOLDER)/$(PUFOLDER)/cbmcombine.c

DOYNAXLZFOLDER     = doynamite_1.0
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/readme.txt
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/decrunch.asm
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/lz.c
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/lz.exe
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/unlzip.c
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/unlzip.exe
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/streaming.asm
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/examples/makefile
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/examples/self_extraction.asm
ZIPLIST           += $(TOOLSFOLDER)/$(DOYNAXLZFOLDER)/examples/self_extractee.prg

BBFOLDER           = bb
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/bb.c
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/bb.h
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/cruncher.c
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/cruncher.h
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/file.c
ZIPLIST           += $(TOOLSFOLDER)/$(BBFOLDER)/file.h

WCRUSHSRCFOLDER    = wcrush
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/Makefile
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/LICENSE.TXT
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/README.TXT
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/decrush/decrush.tas
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/wca/main.cpp
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/wca/wca.exe
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/wcrush/main.cpp
ZIPLIST           += $(TOOLSFOLDER)/$(WCRUSHSRCFOLDER)/wcrush/wcrush.exe


DISKIMAGES         = $(BUILDFOLDER)/loadertest-c64.d64
DISKIMAGES        += $(BUILDFOLDER)/loadertest-c64.d71
DISKIMAGES        += $(BUILDFOLDER)/loadertest-c64.d81
DISKIMAGES        += $(BUILDFOLDER)/loadertest-c16.d64
DISKIMAGES        += $(BUILDFOLDER)/loadertest-c16.d71
DISKIMAGES        += $(BUILDFOLDER)/loadertest-c16.d81

ZIPLIST           += $(DISKIMAGES)


default: prg

loader:
	$(MAKE) -C src

prg bin binary:
	$(MAKE) -C src prg

run:
	$(CD) ..; $(MAKE) -C $(SAMPLESFOLDER)/$(TESTFOLDER) run

$(BUILDFOLDER)/loadertest-c64.d64:
	$(CD) ..; $(MAKE) -C $(SAMPLESFOLDER)/$(TESTFOLDER) all

$(BUILDFOLDER)/loadertest-c16.d64:
	$(CD) ..; $(MAKE) -C $(SAMPLESFOLDER)/$(TESTFOLDER) PLATFORM=c16 all

zip: $(BUILDFOLDER)/loadertest-c64.d64 $(BUILDFOLDER)/loadertest-c16.d64 version.inc
	$(CD) ..; $(ZIP) $(ZIPFILE) $(ZIPLIST)

loadertest: $(BUILDFOLDER)/loadertest-c64.d64 $(BUILDFOLDER)/loadertest-c16.d64 version.inc
	$(CD) ..; $(ZIP_NO_PATHS) $(LOADERTEST) $(DISKIMAGES)


../.svn/entries:
ifeq ($(VERSION),)
	$(MKDIR) ../.svn
	$(TOUCH) $@
endif

version.inc: ../.svn/entries
ifneq ($(VERSION),)
	$(PRINTF) '%s' '.define REPOSITORY_VERSION "' > $@
	$(PRINTF) '%s' $(VERSION) >> $@
	$(PRINTF) '%s' '"' >> $@
endif
