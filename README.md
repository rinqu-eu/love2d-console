# love2d-console
A console for any Love2D project

![alt text](\screenshots\main.png)

## Features (subject to change)
- basic REPL
- basic utf8 support
- basic text editor functionality
   - copy/paste/cut/select all (ctrl + respective keys)
   - selecting text (shift + left/right arrow)
   - jump to begining/end of a word (ctrl + left/right arrow)
   - jump to home/end (Home/End)
- history of executed commands (up/down arrows) (persistant between runs)
- color printing (|cffRRGGBBTEXT|r syntax or use cprint("rrggbb", text))

## Special commands
- **exit** closes console
- **clear** clears output and history
- **qqq** closes Love2D
- **git** prints link to this repo

## Installation
- Copy **console** folder next to your main.lua:
   >/
| -- main.lua
| -- console
|&emsp;&emsp;| -- console.lua
|&emsp;&emsp;| -- \<other console files\>.lua
|&emsp;&emsp;` -- font

- On top of your main file add:
   >local console_toggle = require("console.console")

- In the **love.textinput** function add the following line, **text** should be replaced with whatever is your 1st argument name in **love.textinput**<br>
   >console_toggle(text)

- Use ` to open console
