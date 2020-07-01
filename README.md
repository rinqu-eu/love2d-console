# love2d-console
Ingame console for Love2D

![alt text](https://i.imgur.com/oSsRtCR.png)

## Installation
- Place console folder next to your main.lua:
   >/</br>
| -- main.lua<br>
| -- console/<br>
|&emsp;&emsp;| -- console.lua<br>
|&emsp;&emsp;| -- <other files>.lua<br>
|&emsp;&emsp;` -- font<br>

- On top of your main file add:
   >require("console.console")

- In the **love.textinput** function add:
   >console.toggle(text)

- Use ` to open console

## Features
- printing variables
- utf8 support
- selecting text
- copy, paste, cut
- colored text (with |cffRRGGBBtext|r syntax)
- history of executed commands (up / down arrows)
![alt text](https://i.imgur.com/IkrFHCe.png)

## Special commands
- **exit** closes console
- **git** prints link to this repo
- **clear** clears output and history
- **qqq** closes Love2D
