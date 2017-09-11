console = {}

setmetatable(console, {__index = _G})
setfenv(1, console)

__VERSION = 0.1

git_link = "https://github.com/rinqu-eu/love2d-console"

path = ...
path = path:sub(1, -9):gsub("%p", "/")

font = love.graphics.newFont(path .."/FiraCode.ttf", 14)
font_w = font:getWidth(" ")
font_h = font:getHeight()

background_color = {40, 40, 40, 127}
cursor_style = "block" -- "block" or "line"
cursor_color = {255, 255, 255, 255}
selected_color = {170, 170, 170, 127}
blink_duration = 0.5

is_open = false
is_first_open = false
unhooked = {}

input_buffer = ""
output_buffer = {}
history_buffer = {}

cursor_idx = 0
selected_idx1 = -1
selected_idx2 = -1
history_idx = #history_buffer
output_idx = 0

blink_time = 0

num_output_buffer_lines = 0

do -- helpers
	function isAltDown()
		return love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
	end

	function isCtrlDown()
		return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
	end

	function isShiftDown()
		return love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
	end

	function clamp(min, value, max)
		if (value > max) then
			return max
		elseif (value < min) then
			return min
		else
			return value
		end
	end
end

do -- cursor
	function UpdateCursor()
		local x = 4 + font_w + cursor_idx * font_w
		ui.cursor.x = x
	end

	function MoveCursorRight()
		if (console.ui.selected.visible == true) then
			MoveCursorToPosition(math.max(selected_idx1, selected_idx2))
			DeselectAll()
			return
		end
		cursor_idx = math.min(cursor_idx + 1, input_buffer:len())
		UpdateCursor()
	end

	function MoveCursorLeft()
		if (console.ui.selected.visible == true) then
			MoveCursorToPosition(math.min(selected_idx1, selected_idx2))
			DeselectAll()
			return
		end
		cursor_idx = math.max(0, cursor_idx - 1)
		UpdateCursor()
	end

	function MoveCursorToPosition(pos)
		cursor_idx = clamp(0, pos, input_buffer:len())
		UpdateCursor()
	end

	function MoveCursorByOffset(offset)
		cursor_idx = clamp(0, cursor_idx + offset, input_buffer:len())
		UpdateCursor()
	end

	function MoveCursorHome()
		cursor_idx = 0
		UpdateCursor()
	end

	function MoveCursorEnd()
		cursor_idx = input_buffer:len()
		UpdateCursor()
	end
end

do -- selected
	function UpdateSelected()
		if (selected_idx1 == -1 or selected_idx1 == selected_idx2) then
			ui.selected.visible = false
		else
			local left = math.min(selected_idx1, selected_idx2)
			local right = math.max(selected_idx1, selected_idx2)
			local x = 4 + font_w + left * font_w
			local w = (right - left) * font_w

			ui.selected.x = x
			ui.selected.w = w
			ui.selected.visible = true
		end
	end

	function DeselectAll()
		selected_idx1 = -1
		selected_idx2 = -1

		UpdateSelected()
	end

	function SelectAll()
		selected_idx1 = 0
		selected_idx2 = input_buffer:len()

		MoveCursorEnd()
		UpdateSelected()
	end

	function SelectCursorRight()
		if (cursor_idx == input_buffer:len()) then return end

		if (console.ui.selected.visible == false) then
			selected_idx1 = cursor_idx
		end
		cursor_idx = math.min(cursor_idx + 1, input_buffer:len())
		selected_idx2 = cursor_idx
		UpdateCursor()
		UpdateSelected()
	end

	function SelectCursorLeft()
		if (cursor_idx == 0) then return end

		cursor_idx = math.max(0, cursor_idx - 1)
		if (console.ui.selected.visible == false) then
			selected_idx1 = cursor_idx + 1
		end
		selected_idx2 = cursor_idx
		UpdateCursor()
		UpdateSelected()
	end

	function RemoveSelected()
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)

		local left = input_buffer:sub(1, left_idx)
		local right = input_buffer:sub(right_idx + 1, input_buffer:len())

		input_buffer =  left .. right
		MoveCursorToPosition(left_idx)
		DeselectAll()
	end
end

do -- insert/delete
	function InsertChar(char)
		if (console.ui.selected.visible == true) then
			RemoveSelected()
		end

		if (cursor_idx == input_buffer:len()) then
			input_buffer = input_buffer .. char
		else
			local left = input_buffer:sub(1, cursor_idx)
			local right = input_buffer:sub(cursor_idx + 1, input_buffer:len())

			input_buffer = left .. char .. right
		end

		MoveCursorRight()
	end

	function RemovePrevChar()
		if (console.ui.selected.visible == true) then
			RemoveSelected()
		else
			if (cursor_idx == 0) then return end

			local left = input_buffer:sub(1, cursor_idx - 1)
			local right = input_buffer:sub(cursor_idx + 1, input_buffer:len())

			input_buffer =  left .. right
			MoveCursorLeft()
		end
	end

	function RemoveNextChar()
		if (console.ui.selected.visible == true) then
			RemoveSelected()
		else
			if (cursor_idx == input_buffer:len()) then return end

			local left = input_buffer:sub(1, cursor_idx)
			local right = input_buffer:sub(cursor_idx + 2, input_buffer:len())

			input_buffer =  left .. right
		end
	end

	function Cut()
		if (console.ui.selected.visible == true) then
			local left_idx = math.min(selected_idx1, selected_idx2)
			local right_idx = math.max(selected_idx1, selected_idx2)
			local left = input_buffer:sub(1, left_idx)
			local right = input_buffer:sub(right_idx + 1, input_buffer:len())
			love.system.setClipboardText(input_buffer:sub(left_idx + 1, right_idx))
			input_buffer = left .. right
			MoveCursorToPosition(left_idx)
			DeselectAll()
		end
	end

	function Copy()
		if (console.ui.selected.visible == true) then
			local left_idx = math.min(selected_idx1, selected_idx2)
			local right_idx = math.max(selected_idx1, selected_idx2)
			love.system.setClipboardText(input_buffer:sub(left_idx + 1, right_idx))
		end
	end

	function Paste()
		if (console.ui.selected.visible == true) then
			local left_idx = math.min(selected_idx1, selected_idx2)
			local right_idx = math.max(selected_idx1, selected_idx2)
			local left = input_buffer:sub(1, left_idx)
			local right = input_buffer:sub(right_idx + 1, input_buffer:len())
			input_buffer = left .. love.system.getClipboardText() .. right
			DeselectAll()
		else
			local left = input_buffer:sub(1, cursor_idx)
			local right = input_buffer:sub(cursor_idx + 1, input_buffer:len())
			input_buffer = left .. love.system.getClipboardText() .. right
		end
		MoveCursorByOffset(love.system.getClipboardText():len())
	end

	function ClearInputBuffer()
		input_buffer = ""
		MoveCursorHome()
	end
end

do -- history
	function AddToHistory(msg)
		table.insert(history_buffer, msg)
		history_idx = #history_buffer + 1
	end

	function ClearHistoryBuffer()
		history_buffer = {}
		history_idx = #history_buffer
	end

	function MoveHistoryDown()
		DeselectAll()
		history_idx = math.min(history_idx + 1, #history_buffer + 1)
		if (history_idx == #history_buffer + 1) then
			input_buffer = ""
		else
			input_buffer = history_buffer[history_idx]
		end
		MoveCursorEnd()
	end

	function MoveHistoryUp()
		DeselectAll()
		history_idx = math.max(1, history_idx - 1)
		input_buffer = history_buffer[history_idx] or ""
		MoveCursorEnd()
	end
end

do -- output
	function AddToOutput(msg)
		if (msg == "") then msg = "nil" end
		if (msg == nil) then msg = "nil" end

		msg = tostring(msg)
		table.insert(output_buffer, msg)
	end

	function ClearOutputBuffer()
		output_buffer = {}
		output_idx = 0
	end

	function MoveOutputBy(n)
		output_idx = clamp(0, output_idx + n, math.max(#output_buffer - num_output_buffer_lines, 0))
	end

	function MoveOutputUp()
		MoveOutputBy(10)
	end

	function MoveOutputDown()
		MoveOutputBy(-10)
	end
end

do -- special commands
	function Exit()
		ClearInputBuffer()
		console:Hide()
	end

	function Clear()
		ClearHistoryBuffer()
		ClearOutputBuffer()
		ClearInputBuffer()
	end

	function Quit()
		love.event.quit()
	end

	function Git()
		print(git_link)
		ClearInputBuffer()
	end

	function ClearEsc()
		if (console.ui.selected.visible == true) then
			DeselectAll()
		else
			ClearInputBuffer()
		end
	end
end

function ExecInputBuffer()
	if (input_buffer == "") then return end
	if (input_buffer == "qqq") then Quit() end
	if (input_buffer == "git") then Git() return end
	if (input_buffer == "clear") then Clear() return end
	if (input_buffer == "exit") then Exit() return end

	local func, err = loadstring(input_buffer)

	AddToHistory(input_buffer)
	AddToOutput(input_buffer)

	if (err ~= nil) then
		print(err)
	else
		local status, err = pcall(func)

		if (err ~= nil) then print(err) end

	end
	ClearInputBuffer()
	DeselectAll()
end

function EncodeKey(key)
	local key_encoded = ""
	key_encoded = key_encoded .. (isCtrlDown() and "^" or "")
	key_encoded = key_encoded .. (isShiftDown() and "+" or "")
	key_encoded = key_encoded .. (isAltDown() and "%" or "")

	return key_encoded .. key
end

local key_map = {
	["+1"] = "!",	["+2"] = "@",	["+3"] = "#",	["+4"] = "$",
	["+5"] = "%",	["+6"] = "^",	["+7"] = "&",	["+8"] = "*",
	["+9"] = "(",	["+0"] = ")",	["+-"] = "_",	["+="] = "+",

	["+q"] = "Q",	["+w"] = "W",	["+e"] = "E",	["+r"] = "R",
	["+t"] = "T",	["+y"] = "Y",	["+u"] = "U",	["+i"] = "I",
	["+o"] = "O",	["+p"] = "P",	["+["] = "{",	["+]"] = "}",
	["+\\"] = "|",	["+a"] = "A",	["+s"] = "S",	["+d"] = "D",
	["+f"] = "F",	["+g"] = "G",	["+h"] = "H",	["+j"] = "J",
	["+k"] = "K",	["+l"] = "L",	["+;"] = ":",	["+\'"] = "\"",
	["+z"] = "Z",	["+x"] = "X",	["+c"] = "C",	["+v"] = "V",
	["+b"] = "B",	["+n"] = "N",	["+m"] = "M",	["+,"] = "<",
	["+."] = ">",	["+/"] = "?",	["+`"] = "~",

	["kp1"] = "1",	["kp2"] = "2",	["kp3"] = "3",	["kp4"] = "4",
	["kp5"] = "5",	["kp6"] = "6",	["kp7"] = "7",	["kp8"] = "8",
	["kp9"] = "9",	["kp0"] = "0",	["kp/"] = "/",	["kp*"] = "*",
	["kp-"] = "-",	["kp+"] = "+",

	["kpenter"] = ExecInputBuffer,

	["left"] = MoveCursorLeft,
	["right"] = MoveCursorRight,
	["up"] = MoveHistoryUp,
	["down"] = MoveHistoryDown,

	["+left"] = SelectCursorLeft,
	["+right"] = SelectCursorRight,

	["space"] = " ",

	["escape"] = ClearEsc,

	["home"] = MoveCursorHome,
	["end"] = MoveCursorEnd,
	["pageup"] = MoveOutputUp,
	["pagedown"] = MoveOutputDown,
	["backspace"] = RemovePrevChar,
	["delete"] = RemoveNextChar,
	["return"] = ExecInputBuffer,

	["kpenter"] = ExecInputBuffer,

	["^a"] = SelectAll,
	["^x"] = Cut,
	["^c"] = Copy,
	["^v"] = Paste,
}

do -- hooks and overrides
	function update(dt)
		blink_time = blink_time + dt

		if (blink_time >= blink_duration) then
			ui.cursor.visible = not ui.cursor.visible
			blink_time = blink_time - blink_duration
		end
	end

	function draw()
		DrawUI()
	end

	function wheelmoved(_, dir)
		MoveOutputBy(dir)
	end

	function keypressed(key)
		local key_original = key
		local key_encoded = EncodeKey(key)

		if (key_map[key_encoded] == nil) then
			key = key_original
		else
			key = key_map[key_encoded]
		end

		if (type(key) == "string" and key == key:match(".")) then
			InsertChar(key)
		elseif (type(key) == "function") then
			key()
		else
			-- printf("Unsupported: key: %s\tencoded: %s", key, key_encoded)
		end
	end

end

function MakeUI()
	ui = {}
	ui.background = {x = 0, z = 0, w = love.graphics.getWidth(), h = love.graphics.getHeight() / 3, color = background_color}
	ui.arrow = {x = 2, z = ui.background.h - font_h}
	ui.input = {x = 4 + font_w, z = ui.background.h - font_h}
	ui.output = {}
	local height_left = ui.background.h - font_h
	local i = 0
	while (height_left >= (font_h)) do
		i = i + 1
		ui.output[i] = {x = 4 + font_w, z = ui.background.h - font_h - i * font_h}
		height_left = height_left - font_h
	end
	num_output_buffer_lines = i
	ui.selected = {x = 4 + font_w, z = ui.background.h - font_h, w = 0, h = font_h, color = selected_color, visible = false}
	ui.cursor = {x = 4 + font_w, z = ui.background.h - font_h, w = 1, h = font_h, color = cursor_color, visible = true}
	if (cursor_style == "block") then
		ui.cursor.w = font_w
		ui.cursor.color[4] = 127
	end
	table.insert(output_buffer, git_link)
end

function DrawUI()
	if (ui ~= nil) then
		love.graphics.setColor(ui.background.color)
		love.graphics.rectangle("fill", ui.background.x, ui.background.z, ui.background.w, ui.background.h)
		love.graphics.setColor({255, 255, 255, 255})
		love.graphics.print(">", ui.arrow.x, ui.arrow.z)
		love.graphics.print(input_buffer or "", ui.input.x, ui.input.z)
		for i = 1, num_output_buffer_lines do
			local idx = #output_buffer - i + 1
			love.graphics.print(output_buffer[idx - output_idx] or "", ui.output[i].x, ui.output[i].z)
		end
		if (ui.selected.visible == true) then
			love.graphics.setColor(ui.selected.color)
			love.graphics.rectangle("fill", ui.selected.x, ui.selected.z, ui.selected.w, ui.selected.h)
		end
		if (ui.cursor.visible == true) then
			love.graphics.setColor(ui.cursor.color)
			love.graphics.rectangle("fill", ui.cursor.x, ui.cursor.z, ui.cursor.w, ui.cursor.h)
		end
	end
end

function HookPrint()
	unhooked.print = print
	_G.print = function(...)
		unhooked.print(...)
		AddToOutput(...)
	end
end

function Hook()
	unhooked.key_repeat = love.keyboard.hasKeyRepeat()
	unhooked.font = love.graphics.getFont()
	unhooked.color = {love.graphics.getColor()}
	unhooked.update = love.update
	unhooked.draw = love.draw
	unhooked.wheelmoved = love.wheelmoved
	unhooked.mousepressed = love.mousepressed
	unhooked.mousereleased = love.mousereleased
	unhooked.keypressed = love.keypressed
	unhooked.keyreleased = love.keyreleased
	love.keyboard.setKeyRepeat(true)
	love.graphics.setFont(font)
	love.update = function(dt)
		unhooked.update(dt)
		update(dt)
	end
	love.draw = function()
		love.graphics.setFont(unhooked.font)
		love.graphics.setColor(unhooked.color)
		unhooked.draw()
		love.graphics.setFont(font)
		draw()
	end
	love.wheelmoved = wheelmoved
	love.mousepressed = mousepressed
	love.mousereleased = mousereleased
	love.keypressed = keypressed
	love.keyreleased = keyreleased
end

function UnHook()
	love.keyboard.setKeyRepeat(unhooked.key_repeat)
	love.graphics.setFont(unhooked.font)
	love.graphics.setColor(unhooked.color)
	love.update = unhooked.update
	love.draw = unhooked.draw
	love.wheelmoved = unhooked.wheelmoved
	love.mousepressed = unhooked.mousepressed
	love.mousereleased = unhooked.mousereleased
	love.keypressed = unhooked.keypressed
	love.keyreleased = unhooked.keyreleased
end

function Show()
	if (is_first_open == false) then
		is_first_open = true
		MakeUI()
		HookPrint()
	end
	if (is_open == false) then
		is_open = true
		Hook()
		blink_time = 0
	end
end

function Hide()
	if (is_open == true) then
		is_open = false
		UnHook()
	end
end
