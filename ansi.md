
Style	Code
Bold	\x1B[1m
Faint	\x1B[2m
Italic	\x1B[3m
Underlined	\x1B[4m
Inverse	\x1B[7m
Strikethrough	\x1B[9m

Color	Font code	Background code
Black	\x1B[30m	\x1B[40m
Red	\x1B[31m	\x1B[41m
Green	\x1B[32m	\x1B[42m
Yellow	\x1B[33m	\x1B[43m
Blue	\x1B[34m	\x1B[44m
Magenta	\x1B[35m	\x1B[45m
Cyan	\x1B[36m	\x1B[46m
White	\x1B[37m	\x1B[47m
Any palette color (with V in [0-255])	\x1B[38;5;Vm	\x1B[48;5;Vm
Any RGB color (with values in [0-255])	\x1B[38;2;R;G;Bm	\x1B[48;2;R;G;Bm

Goes back one character	\b
Moves one line up	\x1B[A
Moves n lines up (replace N by the number of lines)	\x1B[NA
Goes back to the begining of the line	\r
Goes back to the begining of the previous line	\x1B[F
Goes back to the begining of the n-th previous line (replace N by the number of lines)	\x1B[NF
Erases the whole line	\x1B[2K

ESC[1;34;{...}m		Set graphics modes for cell, separated by semicolon (;).
ESC[0m		reset all modes (styles and colors)
ESC[1m	ESC[22m	set bold mode.
ESC[2m	ESC[22m	set dim/faint mode.
ESC[3m	ESC[23m	set italic mode.
ESC[4m	ESC[24m	set underline mode.
ESC[5m	ESC[25m	set blinking mode
ESC[7m	ESC[27m	set inverse/reverse mode
ESC[8m	ESC[28m	set hidden/invisible mode
ESC[9m	ESC[29m	set strikethrough mode.

he following escape codes tells the terminal to use the given color ID:

ESC Code Sequence	Description
ESC[38;5;{ID}m	Set foreground color.
ESC[48;5;{ID}m	Set background color.
Where {ID} should be replaced with the color index from 0 to 255 of the following color table:

256 Color table

ESC[={value}h	Changes the screen width or type to the mode specified by value.
ESC[=0h	40 x 25 monochrome (text)
ESC[=1h	40 x 25 color (text)
ESC[=2h	80 x 25 monochrome (text)
ESC[=3h	80 x 25 color (text)
ESC[=4h	320 x 200 4-color (graphics)
ESC[=5h	320 x 200 monochrome (graphics)
ESC[=6h	640 x 200 monochrome (graphics)
ESC[=7h	Enables line wrapping
ESC[=13h	320 x 200 color (graphics)
ESC[=14h	640 x 200 color (16-color graphics)
ESC[=15h	640 x 350 monochrome (2-color graphics)
ESC[=16h	640 x 350 color (16-color graphics)
ESC[=17h	640 x 480 monochrome (2-color graphics)
ESC[=18h	640 x 480 color (16-color graphics)
ESC[=19h	320 x 200 color (256-color graphics)
ESC[={value}l	Resets the mode by using the same values that Set Mode uses, except for 7, which disables line wrapping. The last character in this escape sequence is a lowercase L.

ESC Code Sequence	Description
ESC[?25l	make cursor invisible
ESC[?25h	make cursor visible
ESC[?47l	restore screen
ESC[?47h	save screen
ESC[?1049h	enables the alternative buffer
ESC[?1049l	disables the alternative buffe