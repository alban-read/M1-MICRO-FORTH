LDFLAGS = -syslibroot `xcrun -sdk macosx --show-sdk-path` -lSystem -e _start -arch arm64 
CFLAGS = -lc -e main  
LSTFLGS =
DEBUGFLGS =

all: mf

%.o : %.s
	as -march="armv8.2-a+fp16" $(DEBUGFLGS) $(LSTFLGS) $< -o $@

mf: main.asm
	clang $(CFLAGS) -g  -o mf main.asm addons.c  -O1