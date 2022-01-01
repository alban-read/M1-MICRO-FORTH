LDFLAGS = -syslibroot `xcrun -sdk macosx --show-sdk-path` -lSystem -e _start -arch arm64 
CFLAGS = -lc -e main  
LSTFLGS =
DEBUGFLGS =

all: a64

%.o : %.s
	as -march="armv8.2-a+fp16" $(DEBUGFLGS) $(LSTFLGS) $< -o $@

a64: main.asm
	clang $(CFLAGS) -g  -o a64 main.asm kbhit.c  