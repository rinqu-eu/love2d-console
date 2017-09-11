# love2d-console

Ingame console for Love2D

# Installation

- Create a console folder and put both **console.lua** and **FiraCode.ttf** in it, i.e:
   >/<br>
| -- main.lua<br>
| -- console/<br>
|&emsp;&emsp;| -- console.lua<br>
|&emsp;&emsp;` -- FiraCode.ttf<br>

- On top of your main file add:
   >require("console")
- In the **love.keypressed** function add:
   > if (key == "`") then
  console.Show()
end

  You can change "`" to any key you want.
- Use ` to open console

# Changes to _G

- Added "console" table
- On opening the console overrides your love.keypressed, keyreleased, wheelmoved, mousepressed and mousereleased,
  it also hooks love.update and draw.
  If it's a first time _G.print gets overridden, new print consists of AddToOutput(msg) on top of old print. You can find unchanged print under console.unhooked.print
- On closing the console restores all of your original love.* functions mentioned above.

# Special commands

- exit to close to console
- git to get link to this repo
- clear to clear the output, history
- qqq to close Love2D
