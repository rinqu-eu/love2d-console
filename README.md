# love2d-console
Ingame console for Love2D
## Installation
- Create a console folder and put both **console.lua** and **FiraCode.ttf** in it, i.e:
   >/</br>
| -- main.lua<br>
| -- console/<br>
|&emsp;&emsp;| -- console.lua<br>
|&emsp;&emsp;` -- FiraCode.ttf<br>

- On top of your main file add:
   >require("console.console")

- In the **love.keypressed** function add:
   > if (key == "`") then
  console.Show()
end

- Use ` to open console

## Changes to global enviorment
Loading this library will: 
- add _console_ table
- add _info_, _warn_ and _err_ functions
- hook _print_ so that it also prints to the console
- override your _love.*_ functions when you open a console (with exception of love.update and love.draw)
- restore your _love.*_ functions when you close a console

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
