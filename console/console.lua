console = {}

setmetatable(console, {__index = _G})
setfenv(1, console)

__VERSION = 0.6

local utf8 = require("utf8")

git_link = "https://github.com/rinqu-eu/love2d-console"

path = ...
path_req = path:sub(1, -9)
path_load = path:sub(1, -9):gsub("%.", "/")

font = love.graphics.newFont(path_load .. "/FiraCode.ttf", 13)
font_w = font:getWidth(" ")
font_h = font:getHeight()

background_color = {40 / 255, 40 / 255, 40 / 255, 127 / 255}
cursor_style = "block" -- "block" or "line"
cursor_color = {255 / 255, 255 / 255, 255 / 255, 255 / 255}
selected_color = {170 / 255, 170 / 255, 170 / 255, 127 / 255}
blink_duration = 0.5
output_jump_by = 7

color_info = "429bf4"
color_warn = "cecb2f"
color_err = "ea2a2a"
color_com = "00cc00"

is_open = false
is_first_open = false
unhooked = {}

input_buffer = ""
output_buffer = {}
history_buffer = {}

cursor_idx = 0
selected_idx1 = -1
selected_idx2 = -1
history_idx = #history_buffer + 1
output_idx = 0

blink_time = 0

num_output_buffer_lines = 0

-- helpers
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

function utf8.sub(s, i, j)
	assert(type(s) == "number" or type(s) == "string", string.format("bad argument #1 to 'sub' (string expected, got %s)", type(s) ~= "nil" and type(s) or "no value"))
	assert(type(i) == "number" or type(tonumber(i)) == "number", string.format("bad argument #2 to 'sub' (number expected, got %s)", type(i) ~= "nil" and type(i) or "no value"))
	assert(type(j) == "nil" or type(j) == "number" or type(tonumber(j) == "number"), string.format("bad argument #3 to 'sub' (number expeted, got %s)",	type(i)))
	s, i, j = tostring(s), tonumber(i), tonumber(j)

	local offset_i, offset_j
	local s_len = utf8.len(s)

	if (i > s_len) then
		offset_i = utf8.offset(s, s_len + 1)
	elseif (i < -s_len) then
		offset_i = 0
	else
		offset_i = utf8.offset(s, i)
	end

	if (j ~= nil) then
		if (j > s_len or j == -1) then
			offset_j = utf8.offset(s, s_len + 1) - 1
		elseif (j < -s_len) then
			offset_j = 0
		else
			offset_j = utf8.offset(s, j + 1) - 1
		end
	end

	return string.sub(s, offset_i, offset_j)
end

-- this is some basic utf8.find that works for just the things I need it to
function utf8.find(s, pattern, index)
	assert(type(s) == "number" or type(s) == "string", string.format("bad argument #1 to 'find' (string expected, got %s)", type(s) ~= "nil" and type(s) or "no value"))
	assert(type(pattern) == "number" or type(pattern) == "string", string.format("bad argument #2 to 'find' (string expected, got %s)", type(pattern) ~= "nil" and type(pattern) or "no value"))
	s, pattern, index = tostring(s), tostring(pattern), index or 1

	local function depattern(pattern) local tp = {"%%x", "%%.", "%%[", "%%]"} local td = {"x", ".", "[", "]"} local p = pattern for i, v in pairs(tp) do pattern = string.gsub(pattern, v, td[i]) end return pattern end
	local s_len = utf8.len(s)
	local p_len = string.len(depattern(pattern))

	for i = index, s_len do
		local s_ = utf8.sub(s, i, i + p_len - 1)

		if (string.find(s_, pattern) ~= nil) then
			return i, i + p_len - 1
		end
	end

	return nil
end

-- cursor
function ResetBlink()
	blink_time = 0
	ui.cursor.visible = true
end

function UpdateCursor()
	local x = 4 + font_w + cursor_idx * font_w

	ResetBlink()
	ui.cursor.x = x
end

function MoveCursorRight()
	if (console.ui.selected.visible == true) then
		MoveCursorToPosition(math.max(selected_idx1, selected_idx2))
		DeselectAll()
		return
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
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
	cursor_idx = clamp(0, pos, utf8.len(input_buffer))
	UpdateCursor()
end

function MoveCursorByOffset(offset)
	cursor_idx = clamp(0, cursor_idx + offset, utf8.len(input_buffer))
	UpdateCursor()
end

function MoveCursorHome()
	cursor_idx = 0
	DeselectAll()
	UpdateCursor()
end

function MoveCursorEnd()
	cursor_idx = utf8.len(input_buffer)
	DeselectAll()
	UpdateCursor()
end

function JumpCursorLeft()
	if (string.match(utf8.sub(input_buffer, cursor_idx, cursor_idx), "%p") ~= nil) then
		cursor_idx = math.max(0, cursor_idx - 1)
	else
		local p_idx

		for i = cursor_idx - 1, 0, -1 do
			if (string.match(utf8.sub(input_buffer, i, i), "%p") ~= nil) then
				p_idx = i
				break
			end
		end

		cursor_idx = p_idx or 0
	end

	UpdateCursor()
end

function JumpCursorRight()
	if (string.match(utf8.sub(input_buffer, cursor_idx + 1, cursor_idx + 1), "%p") ~= nil) then
		cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	else
		local p_idx

		for i = cursor_idx, utf8.len(input_buffer) do
			if (string.match(utf8.sub(input_buffer, i + 1, i + 1), "%p") ~= nil) then
				p_idx = i
				break
			end
		end

		cursor_idx = p_idx or utf8.len(input_buffer)
	end

	UpdateCursor()
end

 -- selected
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
	cursor_idx = utf8.len(input_buffer)
	selected_idx1 = 0
	selected_idx2 = cursor_idx
	UpdateCursor()
	UpdateSelected()
end

function SelectCursorRight()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	selected_idx2 = cursor_idx
	UpdateCursor()
	UpdateSelected()
end

function SelectCursorLeft()
	if (cursor_idx == 0) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = math.max(0, cursor_idx - 1)
	selected_idx2 = cursor_idx
	UpdateCursor()
	UpdateSelected()
end

function RemoveSelected()
	local left_idx = math.min(selected_idx1, selected_idx2)
	local right_idx = math.max(selected_idx1, selected_idx2)

	local left = utf8.sub(input_buffer, 1, left_idx)
	local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

	input_buffer =  left .. right
	MoveCursorToPosition(left_idx)
	DeselectAll()
end

function SelectHome()
	if (cursor_idx == 0) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = 0
	selected_idx2 = cursor_idx
	UpdateSelected()
	UpdateCursor()
end

function SelectEnd()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = utf8.len(input_buffer)
	selected_idx2 = cursor_idx
	UpdateSelected()
	UpdateCursor()
end

function SelectJumpCursorLeft()
	if (cursor_idx == 0) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	if (string.match(utf8.sub(input_buffer, cursor_idx, cursor_idx), "%p") ~= nil) then
		cursor_idx = math.max(0, cursor_idx - 1)
	else
		local p_idx

		for i = cursor_idx - 1, 0, -1 do
			if (string.match(utf8.sub(input_buffer, i, i), "%p") ~= nil) then
				p_idx = i
				break
			end
		end

		cursor_idx = p_idx or 0
	end

	selected_idx2 = cursor_idx
	UpdateSelected()
	UpdateCursor()
end

function SelectJumpCursorRight()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	if (string.match(utf8.sub(input_buffer, cursor_idx + 1, cursor_idx + 1), "%p") ~= nil) then
		cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	else
		local p_idx

		for i = cursor_idx, utf8.len(input_buffer) do
			if (string.match(utf8.sub(input_buffer, i + 1, i + 1), "%p") ~= nil) then
				p_idx = i
				break
			end
		end

		cursor_idx = p_idx or utf8.len(input_buffer)
	end

	selected_idx2 = cursor_idx
	UpdateSelected()
	UpdateCursor()
end

-- insert/delete
function InsertChar(char)
	if (input_buffer == "" and char == "`") then return end

	if (console.ui.selected.visible == true) then
		RemoveSelected()
	end

	if (cursor_idx == utf8.len(input_buffer)) then
		input_buffer = input_buffer .. char
	else
		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. char .. right
	end

	MoveCursorRight()
end

function RemovePrevChar()
	if (console.ui.selected.visible == true) then
		RemoveSelected()
	else
		if (cursor_idx == 0) then return end

		local left = utf8.sub(input_buffer, 1, cursor_idx - 1)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer =  left .. right
		MoveCursorLeft()
	end
end

function RemoveNextChar()
	if (console.ui.selected.visible == true) then
		RemoveSelected()
	else
		if (cursor_idx == utf8.len(input_buffer)) then return end

		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 2, utf8.len(input_buffer))

		input_buffer =  left .. right
	end
end

function Cut()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)
		local left = utf8.sub(input_buffer, 1, left_idx)
		local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

		love.system.setClipboardText(utf8.sub(input_buffer, left_idx + 1, right_idx))
		input_buffer = left .. right
		MoveCursorToPosition(left_idx)
		DeselectAll()
	end
end

function Copy()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)

		love.system.setClipboardText(utf8.sub(input_buffer, left_idx + 1, right_idx))
	end
end

function Paste()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)
		local left = utf8.sub(input_buffer, 1, left_idx)
		local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. love.system.getClipboardText() .. right
		DeselectAll()
	else
		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. love.system.getClipboardText() .. right
	end

	MoveCursorByOffset(utf8.len(love.system.getClipboardText()))
end

function ClearInputBuffer()
	input_buffer = ""
	MoveCursorHome()
end

-- history
function AddToHistory(msg)
	table.insert(history_buffer, msg)
	history_idx = #history_buffer + 1
end

function ClearHistoryBuffer()
	history_buffer = {}
	history_idx = #history_buffer + 1
end

function MoveHistoryDown()
	history_idx = math.min(history_idx + 1, #history_buffer + 1)

	if (history_idx == #history_buffer + 1) then
		input_buffer = ""
	else
		input_buffer = history_buffer[history_idx]
	end

	MoveCursorEnd()
end

function MoveHistoryUp()
	history_idx = math.max(1, history_idx - 1)
	input_buffer = history_buffer[history_idx] or ""
	MoveCursorEnd()
end

-- output
function AddToOutput(...)
	local arg = {...}
	local narg = select("#", ...)

	for i = 1, narg do
		arg[i] = tostring(arg[i])
	end

	msg = parse(table.concat(arg, " "))
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
	MoveOutputBy(output_jump_by)
end

function MoveOutputDown()
	MoveOutputBy(-output_jump_by)
end

-- special commands
function Exit()
	ClearInputBuffer()
	console.Hide()
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

function ExecInputBuffer()
	if (input_buffer == "") then return end
	if (input_buffer == "qqq") then Quit() return end
	if (input_buffer == "git") then Git() return end
	if (input_buffer == "clear") then Clear() return end
	if (input_buffer == "exit") then Exit() return end

	local func, err = loadstring(input_buffer)

	AddToHistory(input_buffer)
	AddToOutput("|cff" .. color_com .. "exec: |r" .. input_buffer)

	if (err ~= nil) then
		print(parse_(input_buffer))
	else
		local status, err = pcall(func)

		if (err ~= nil) then
			print("pcall: " .. err)
		end
	end

	ClearInputBuffer()
	DeselectAll()
end

function parse_(msg)
	local queue = {}
	local enqueue = function(v)	table.insert(queue, v) end
	local dequeue = function() local v = queue[1] table.remove(queue, 1) return v end
	local num_loops = 0

	while (msg ~= "") do
		if (num_loops >= 15) then
			err("Something went horribly wrong (either the parser failed somehow")
			err("or the variable is nested too deep, >= 15), please report this")
			return nil
		end

		local dot_idx = utf8.find(msg, "%.") or math.huge
		local bra_idx = utf8.find(msg, "%[") or math.huge
		local first_idx = math.min(dot_idx, bra_idx)

		if (dot_idx == 1) then
			msg = utf8.sub(msg, 2)
		elseif (bra_idx == 1) then
			local end_idx = utf8.find(msg, "%]")
			if (utf8.sub(msg, 2, 2) == "\"") then
				enqueue(utf8.sub(msg, 3, end_idx - 2))
			else
				enqueue(tonumber(utf8.sub(msg, 2, end_idx - 1)))
			end
			msg = utf8.sub(msg, end_idx + 1)
		else
			enqueue(utf8.sub(msg, 1, first_idx - 1))
			msg = utf8.sub(msg, first_idx)
		end

		num_loops = num_loops + 1
	end

	local value

	while (#queue > 0) do
		local t = dequeue()

		if (value == nil) then
			value = _G[t]
		else
			if (type(value) == "table" and value[t] ~= nil) then
				value = value[t]
			else
				value =  nil
			end
		end
	end

	return tostring(value)
end

function EncodeKey(key)
	local key_encoded = ""

	key_encoded = key_encoded .. (isCtrlDown() and "^" or "")
	key_encoded = key_encoded .. (isShiftDown() and "+" or "")
	key_encoded = key_encoded .. (isAltDown() and "%" or "")

	return key_encoded .. key
end

function parse(text)
	local parsed = {}

	local color_stack = {}
	local push = function(color) table.insert(color_stack, color) end
	local pop = function() if (#color_stack > 0) then table.remove(color_stack, #color_stack) end end
	local peek = function() if (#color_stack > 0) then return color_stack[#color_stack] end end
	local torgb = function(hex) return {tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), 255} end
	local offset = 1

	local c_tag = "|c%x%x%x%x%x%x%x%x"
	local c_tag_len = 10
	local r_tag = "|r"
	local r_tag_len = 2

	while (offset <= utf8.len(text)) do
		local t = utf8.sub(text, offset)
		local c_idx = utf8.find(t, c_tag)
		local r_idx = utf8.find(t, r_tag)

		if (c_idx == 1) then
			local color = utf8.sub(t, c_idx + 4, c_idx + 9)

			push(color)
			offset = offset + c_tag_len
		elseif (r_idx == 1) then
			pop()
			offset = offset + r_tag_len
		else
			local next_tag_idx = (c_idx or r_idx) and math.min(c_idx or math.huge, r_idx or math.huge) or 0
			local text = utf8.sub(t, 1, next_tag_idx - 1)

			table.insert(parsed, {color = peek() or "ffffff", text = text or ""})

			offset = offset + utf8.len(text)
		end
	end

	if (#parsed == 0) then
		table.insert(parsed, {color = "ffffff", text = ""})
	end

	local usable = {}

	for i = 1, #parsed do
		table.insert(usable, torgb(parsed[i].color))
		table.insert(usable, parsed[i].text)
	end

	return usable
end

function _G.warn(...)
	AddToOutput("|cff" .. color_warn .. "warning:|r", ...)
end

function _G.err(...)
	AddToOutput("|cff" .. color_err .. "error:|r", ...)
end

function _G.info(...)
	AddToOutput("|cff" .. color_info .. "info:|r", ...)
end

function Show()
	if (is_first_open == false) then
		is_first_open = true
		MakeUI()
		HookPrint()
		HookClose()
	end

	if (is_open == false) then
		is_open = true
		Hook()
		ResetBlink()
	end
end

function Hide()
	if (is_open == true) then
		is_open = false
		UnHook()
	end
end

keybinds = {
	["kpenter"] = ExecInputBuffer,

	["up"] = MoveHistoryUp,
	["down"] = MoveHistoryDown,

	["left"] = MoveCursorLeft,
	["right"] = MoveCursorRight,

	["+left"] = SelectCursorLeft,
	["+right"] = SelectCursorRight,

	["^left"] = JumpCursorLeft,
	["^right"] = JumpCursorRight,

	["^+left"] = SelectJumpCursorLeft,
	["^+right"] = SelectJumpCursorRight,

	["+home"] = SelectHome,
	["+end"] = SelectEnd,

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

	["`"] = Hide
}

-- hooks and overrides
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
	local key_encoded = EncodeKey(key)

	if (keybinds[key_encoded] ~= nil) then
		keybinds[key_encoded]()
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
	table.insert(output_buffer, "Press ` or type 'exit' to close")
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

function HookClose()
	unhooked.quit = love.quit

	_G.love.quit = function(...)
		local f_history = io.open(love.filesystem.getSource() .. "/" .. path_load .. "/history.txt", "w+")
		local low = math.max(1, #history_buffer - 30 + 1)

		for i = low, #history_buffer do
			f_history:write(history_buffer[i] .. "\n")
		end
		f_history:close()

		if (unhooked.quit ~= nil) then
			unhooked.quit(...)
		end
	end
end

function textinput(key)
	InsertChar(key)
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
	unhooked.textinput = love.textinput

	love.keyboard.setKeyRepeat(true)
	love.graphics.setFont(font)
	love.update = function(dt)
		if (unhooked.update ~= nil) then
			unhooked.update(dt)
		end
		update(dt)
	end
	love.draw = function()
		love.graphics.setFont(unhooked.font)
		love.graphics.setColor(unhooked.color)
		if (unhooked.draw ~= nil) then
			unhooked.draw()
		end
		love.graphics.setFont(font)
		draw()
	end
	love.wheelmoved = wheelmoved
	love.mousepressed = mousepressed
	love.mousereleased = mousereleased
	love.keypressed = keypressed
	love.keyreleased = keyreleased
	love.textinput = textinput
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
	love.textinput = unhooked.textinput
end

do
	local f_history = io.open(love.filesystem.getSource() .. "/" .. path_load .. "/history.txt", "r")
	if (f_history == nil) then
		f_history = io.open(love.filesystem.getSource() .. "/" .. path_load .. "/history.txt", "w")
		f_history:close()
		f_history = nil
	else
		line = f_history:read("*line")
		while (line ~= nil) do
			table.insert(history_buffer, line)
			line = f_history:read("*line")
		end
		history_idx = #history_buffer + 1
		f_history:close()
		f_history = nil
	end
end
