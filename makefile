frisc64: frisc64.o
	ld -o frisc64 frisc64.o -lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -e _start -arch arm64 

frisc64.o: main.asm
	as -o frisc64.o main.asm