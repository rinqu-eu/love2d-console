-- #region setup
console = {}

setmetatable(console, {__index = _G})
setfenv(1, console)

__VERSION = 0.6

git_link = "https://github.com/rinqu-eu/love2d-console"

path = ...
path_req = path:sub(1, -9)
path_load = path:sub(1, -9):gsub("%.", "/")

local utf8 = require(path_req .. ".utf8")
local math = require(path_req .. ".math")

font = love.graphics.newFont(path_load .. "/font/FiraCode.ttf", 13)
font_w = font:getWidth(" ")
font_h = font:getHeight()


background_color = {0.16, 0.16, 0.16, 0.50}
cursor_style = "block" -- "block" or "line"
cursor_color = {1.00, 1.00, 1.00, 1.00}
selected_color = {0.67, 0.67, 0.67, 0.50}

blink_duration = 0.5
output_jump_by = 7

close_key = '`'

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
-- #endregion setup

-- #region helpers misc
function is_alt_key_down()
	return love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
end

function is_ctrl_key_down()
	return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
end

function is_shift_key_down()
	return love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
end

-- #endregion helpers

-- #region cursor
function reset_blink()
	blink_time = 0
	ui.cursor.visible = true
end

function update_cursor()
	local x = 4 + font_w + cursor_idx * font_w

	reset_blink()
	ui.cursor.x = x
end

function move_cursor_right()
	if (console.ui.selected.visible == true) then
		move_cursor_to_position(math.max(selected_idx1, selected_idx2))
		deselect_all()
		return
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	update_cursor()
end

function move_cursor_left()
	if (console.ui.selected.visible == true) then
		move_cursor_to_position(math.min(selected_idx1, selected_idx2))
		deselect_all()
		return
	end

	cursor_idx = math.max(0, cursor_idx - 1)
	update_cursor()
end

function move_cursor_to_position(pos)
	cursor_idx = math.clamp(0, pos, utf8.len(input_buffer))
	update_cursor()
end

function move_cursor_by_offset(offset)
	cursor_idx = math.clamp(0, cursor_idx + offset, utf8.len(input_buffer))
	update_cursor()
end

function move_cursor_home()
	cursor_idx = 0
	deselect_all()
	update_cursor()
end

function move_cursor_end()
	cursor_idx = utf8.len(input_buffer)
	deselect_all()
	update_cursor()
end

function jump_cursor_left()
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

	update_cursor()
end

function jump_cursor_right()
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

	update_cursor()
end
-- #endregion cursor

-- #region selected
function update_selected()
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

function deselect_all()
	selected_idx1 = -1
	selected_idx2 = -1

	update_selected()
end

function select_all()
	cursor_idx = utf8.len(input_buffer)
	selected_idx1 = 0
	selected_idx2 = cursor_idx
	update_cursor()
	update_selected()
end

function select_cursor_right()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	selected_idx2 = cursor_idx
	update_cursor()
	update_selected()
end

function select_cursor_left()
	if (cursor_idx == 0) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = math.max(0, cursor_idx - 1)
	selected_idx2 = cursor_idx
	update_cursor()
	update_selected()
end

function remove_selected()
	local left_idx = math.min(selected_idx1, selected_idx2)
	local right_idx = math.max(selected_idx1, selected_idx2)

	local left = utf8.sub(input_buffer, 1, left_idx)
	local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

	input_buffer =  left .. right
	move_cursor_to_position(left_idx)
	deselect_all()
end

function select_home()
	if (cursor_idx == 0) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = 0
	selected_idx2 = cursor_idx
	update_selected()
	update_cursor()
end

function select_end()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (console.ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = utf8.len(input_buffer)
	selected_idx2 = cursor_idx
	update_selected()
	update_cursor()
end

function select_jump_cursor_left()
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
	update_selected()
	update_cursor()
end

function select_jump_cursor_right()
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
	update_selected()
	update_cursor()
end
-- #endregion selected

-- #region insert/delete
function inset_character(char)
	if (console.ui.selected.visible == true) then
		remove_selected()
	end

	if (cursor_idx == utf8.len(input_buffer)) then
		input_buffer = input_buffer .. char
	else
		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. char .. right
	end

	move_cursor_right()
end

function remove_prev_character()
	if (console.ui.selected.visible == true) then
		remove_selected()
	else
		if (cursor_idx == 0) then return end

		local left = utf8.sub(input_buffer, 1, cursor_idx - 1)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer =  left .. right
		move_cursor_left()
	end
end

function remove_next_character()
	if (console.ui.selected.visible == true) then
		remove_selected()
	else
		if (cursor_idx == utf8.len(input_buffer)) then return end

		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 2, utf8.len(input_buffer))

		input_buffer =  left .. right
	end
end

function cut()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)
		local left = utf8.sub(input_buffer, 1, left_idx)
		local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

		love.system.setClipboardText(utf8.sub(input_buffer, left_idx + 1, right_idx))
		input_buffer = left .. right
		move_cursor_to_position(left_idx)
		deselect_all()
	end
end

function copy()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)

		love.system.setClipboardText(utf8.sub(input_buffer, left_idx + 1, right_idx))
	end
end

function paste()
	if (console.ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)
		local left = utf8.sub(input_buffer, 1, left_idx)
		local right = utf8.sub(input_buffer, right_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. love.system.getClipboardText() .. right
		deselect_all()
	else
		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 1, utf8.len(input_buffer))

		input_buffer = left .. love.system.getClipboardText() .. right
	end

	move_cursor_by_offset(utf8.len(love.system.getClipboardText()))
end

function clear_input_buffer()
	input_buffer = ""
	move_cursor_home()
end
-- #endregion insert/delete

-- #region history
function add_to_history(msg)
	table.insert(history_buffer, msg)
	history_idx = #history_buffer + 1
end

function clear_history_buffer()
	history_buffer = {}
	history_idx = #history_buffer + 1
end

function move_history_down()
	history_idx = math.min(history_idx + 1, #history_buffer + 1)

	if (history_idx == #history_buffer + 1) then
		input_buffer = ""
	else
		input_buffer = history_buffer[history_idx]
	end

	move_cursor_end()
end

function move_history_up()
	history_idx = math.max(1, history_idx - 1)
	input_buffer = history_buffer[history_idx] or ""
	move_cursor_end()
end
-- #endregion history

-- #region output
function add_to_output(...)
	local arg = {...}
	local narg = select("#", ...)

	for i = 1, narg do
		arg[i] = tostring(arg[i])
	end

	msg = parse(table.concat(arg, " "))
	table.insert(output_buffer, msg)
end

function clear_output_history()
	output_buffer = {}
	output_idx = 0
end

function move_output_by(n)
	output_idx = math.clamp(0, output_idx + n, math.max(#output_buffer - num_output_buffer_lines, 0))
end

function move_output_up()
	move_output_by(output_jump_by)
end

function move_output_down()
	move_output_by(-output_jump_by)
end
-- #endregion output

-- #region special commands
function exit()
	clear_input_buffer()
	console.hide()
end

function clear()
	clear_history_buffer()
	clear_output_history()
	clear_input_buffer()
end

function quit()
	love.event.quit()
end

function git()
	print(git_link)
	clear_input_buffer()
end

function clear_esc()
	if (console.ui.selected.visible == true) then
		deselect_all()
	else
		clear_input_buffer()
	end
end

function exec_input_buffer()
	if (input_buffer == "") then return end
	if (input_buffer == "qqq") then quit() return end
	if (input_buffer == "git") then git() return end
	if (input_buffer == "clear") then clear() return end
	if (input_buffer == "exit") then exit() return end

	local func, err = loadstring(input_buffer)

	add_to_history(input_buffer)
	add_to_output("|cff" .. color_com .. "exec: |r" .. input_buffer)

	if (err ~= nil) then
		print(parse_(input_buffer))
	else
		local status, err = pcall(func)

		if (err ~= nil) then
			print("pcall: " .. err)
		end
	end

	clear_input_buffer()
	deselect_all()
end
-- #endregion special commands

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

function encode_key(key)
	local key_encoded = ""

	key_encoded = key_encoded .. (is_ctrl_key_down() and "^" or "")
	key_encoded = key_encoded .. (is_shift_key_down() and "+" or "")
	key_encoded = key_encoded .. (is_alt_key_down() and "%" or "")

	return key_encoded .. key
end

function parse(text)
	local parsed = {}

	local color_stack = {}
	local push = function(color) table.insert(color_stack, color) end
	local pop = function() if (#color_stack > 0) then table.remove(color_stack, #color_stack) end end
	local peek = function() if (#color_stack > 0) then return color_stack[#color_stack] end end
	local torgb = function(hex) return {tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1} end
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
	add_to_output("|cff" .. color_warn .. "warning:|r", ...)
end

function _G.err(...)
	add_to_output("|cff" .. color_err .. "error:|r", ...)
end

function _G.info(...)
	add_to_output("|cff" .. color_info .. "info:|r", ...)
end

function _G.cprint(color, ...)
	assert(string.len(color) == 6)

	unhooked.print(...)
	add_to_output("|cff" .. color .. "info:|r", ...)
end

function show(opt_close_key)
	if opt_close_key then
		close_key = opt_close_key
	end

	if (is_first_open == false) then
		is_first_open = true
		make_ui()
		hook_print()
		hook_close()
	end

	if (is_open == false) then
		is_open = true
		resize(love.graphics.getWidth(), love.graphics.getHeight())
		hook()
		reset_blink()
	end
end

function hide()
	if (is_open == true) then
		is_open = false
		unhook()
	end
end

keybinds = {
	["kpenter"] = exec_input_buffer,

	["up"] = move_history_up,
	["down"] = move_history_down,

	["left"] = move_cursor_left,
	["right"] = move_cursor_right,

	["+left"] = select_cursor_left,
	["+right"] = select_cursor_right,

	["^left"] = jump_cursor_left,
	["^right"] = jump_cursor_right,

	["^+left"] = select_jump_cursor_left,
	["^+right"] = select_jump_cursor_right,

	["+home"] = select_home,
	["+end"] = select_end,

	["escape"] = clear_esc,

	["home"] = move_cursor_home,
	["end"] = move_cursor_end,
	["pageup"] = move_output_up,
	["pagedown"] = move_output_down,
	["backspace"] = remove_prev_character,
	["delete"] = remove_next_character,
	["return"] = exec_input_buffer,

	["kpenter"] = exec_input_buffer,

	["^a"] = select_all,
	["^x"] = cut,
	["^c"] = copy,
	["^v"] = paste
}

-- #region hooks and overrides
function update(dt)
	blink_time = blink_time + dt

	if (blink_time >= blink_duration) then
		ui.cursor.visible = not ui.cursor.visible
		blink_time = blink_time - blink_duration
	end
end

function draw()
	draw_ui()
end

function wheelmoved(_, dir)
	move_output_by(dir)
end

function keypressed(key)
	local key_encoded = encode_key(key)

	if (keybinds[key_encoded] ~= nil) then
		keybinds[key_encoded]()
	end
end

function resize(w, h)
	ui.background = {x = 0, z = 0, w = w, h = h / 3, color = background_color}
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
		ui.cursor.color[4] = 0.498039216
	end
end
-- #endregion hooks and overrides

function make_ui()
	ui = {}
	resize(love.graphics.getWidth(), love.graphics.getHeight())

	table.insert(output_buffer, git_link)
	table.insert(output_buffer, "Press ` or type 'exit' to close")
end

function draw_ui()
	if (ui ~= nil) then
		love.graphics.setColor(ui.background.color)
		love.graphics.rectangle("fill", ui.background.x, ui.background.z, ui.background.w, ui.background.h)
		love.graphics.setColor({1, 1, 1, 1})
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

function hook_print()
	unhooked.print = print

	_G.print = function(...)
		unhooked.print(...)
		add_to_output(...)
	end
end

function hook_close()
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
	if (input_buffer == "" and key == close_key) then return hide() end
	inset_character(key)
end

function hook()
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
	unhooked.resize = love.resize

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
	love.resize = function(w, h)
		if (unhooked.resize ~= nil) then
			unhooked.resize(w, h)
		end
		resize(w, h)
	end
	love.wheelmoved = wheelmoved
	love.mousepressed = mousepressed
	love.mousereleased = mousereleased
	love.keypressed = keypressed
	love.keyreleased = keyreleased
	love.textinput = textinput
end

function unhook()
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
	love.resize = unhooked.resize
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

show()
hide()
