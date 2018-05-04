#include "bb.h"
#include "file.h"
#include "cruncher.h"
#include <stdio.h>

int main(int argc, char * argv[])
{
  File myFile;
  File myBBFile;
  char* fileName;
  bool attachDecruncher = false;
  bool isRelocated = false;
  uint startAdress = 0;
  decruncherType theDecrType = noDecr;

  if((argc != 2 && argc != 4) ||
     (strcmp(argv[1], "-h") == 0) ||
     (strcmp(argv[1], "-help") == 0)){
    printf("Usage: bb [-[c|d|e|r] xxxx] <filename>\n");
    printf("   -c: Make executable with decruncher.\n");
    printf("   -d: Make executable with decruncher and d020-effect.\n");
    printf("   -e: Make executable with loader init and decruncher.\n");
    printf("   -r: Relocate file.\n");
    printf("   xxxx: 16 bit hex adress.\n");
    return 0;
  }

  if(argc == 2) {
    fileName = argv[1];
  } else {
    int i;
    char *s = argv[2];
    fileName = argv[3];
    attachDecruncher = true;

    if(strcmp(argv[1], "-d") == 0)
      theDecrType = normalDecr;
    else if(strcmp(argv[1], "-e") == 0)
      theDecrType = loadInitDecr;
    else if(strcmp(argv[1], "-c") == 0)
      theDecrType = cleanDecr;
    else if(strcmp(argv[1], "-r") == 0)
      isRelocated = true;
    else {
      printf("Don't understand, aborting.\n");
      return -1;
    }
    if(strlen(s) != 4){
      printf("Don't understand, aborting.\n");
      return -1;
    }

    for(i = 0; i < 4; ++i){
      byte c;
      if(s[i] >= '0' && s[i] <= '9') c = s[i] - '0';
      if(s[i] >= 'a' && s[i] <= 'f') c = s[i] - 'a' + 10;
      if(s[i] >= 'A' && s[i] <= 'F') c = s[i] - 'A' + 10;
      startAdress *= 16;
      startAdress += c;
    }
  }

  if(!readFile(&myFile, fileName)) {
    printf("Error (B-1): Open file \"%s\", aborting.\n", fileName);
    return -1;
  }

  if(!crunch(&myFile, &myBBFile, startAdress, theDecrType, isRelocated)) {
    freeFile(&myFile);
    return -1;
  }

  if(!writeFile(&myBBFile, myFile.name)) {
    printf("Error (B-2): Write file \"%s\", aborting.\n", myBBFile.name);
  }

  printf("ByteBoozer: \"%s\" -> \"%s\"\n", myFile.name, myBBFile.name);

  freeFile(&myFile);
  freeFile(&myBBFile);

  return 0;
}
