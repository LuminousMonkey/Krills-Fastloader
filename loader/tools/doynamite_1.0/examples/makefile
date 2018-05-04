self_extraction.prg : self_extraction.asm self_extractee.lz
	64tass -o $@ self_extraction.asm

self_extractee.lz : self_extractee.prg
	../lz -o $@ $<