LDFLAGS = -syslibroot `xcrun -sdk macosx --show-sdk-path` -lSystem -e _start -arch arm64
CFLAGS = -lc -e main
LSTFLGS =
DEBUGFLGS =


all: frisc

%.o : %.s
	as -march="armv8.2-a+fp16" $(DEBUGFLGS) $(LSTFLGS) $< -o $@

frisc: main.asm
	clang $(CFLAGS) -g -o frisc64 main.asm 