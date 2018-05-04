
doynax_lz: lz.o
	gcc -o ../$@ $?

lz.o: lz.c
	gcc -c -o $@ $?

doynax_unlz: unlzip.o
	gcc -o ../$@ $?

unlzip.o: unlzip.c
	gcc -c -o $@ $?

clean:
	rm -rf *.o ../doynax_lz ../doynax_lz.exe ../doynax_unlz ../doynax_unlz.exe *~
