-- #region setup
local console = {}

setmetatable(console, {__index = _G})
setfenv(1, console)

__VERSION = 0.6

git_link = "https://github.com/rinqu-eu/love2d-console"

path = ...
path_req = path:sub(1, -9)
path_load = path:sub(1, -9):gsub("%.", "/")

local utf8 = require(path_req .. ".utf8")
local util = require(path_req .. ".util")
local parse = require(path_req .. ".parse")

font = love.graphics.newFont(path_load .. "/font/FiraCode.ttf", 13)
font_w = font:getWidth(" ")
font_h = font:getHeight()

background_color = util.to_rgb_table("#2929297F")
selected_color = util.to_rgb_table("#ABABAB7F")

cursor_block_color = util.to_rgb_table("#FFFFFF7F")
cursor_line_color = util.to_rgb_table("#FFFFFFFF")
cursor_style = "block" -- "block" or "line"
cursor_blink_duration = 0.5

output_jump_by = 7

toggle_key = "`"

color_info = "429bf4ff"
color_warn = "cecb2fff"
color_err = "ea2a2aff"
color_com = "00cc00ff"

is_open = false
unhooked = {}

input_buffer = ""
output_buffer = {}
history_buffer = {}

cursor_idx = 0
selected_idx1 = -1
selected_idx2 = -1
history_idx = #history_buffer + 1
output_idx = 0

num_output_buffer_lines = 0

scroll_output_on_exec = true
expose_output_functions = false

-- internals
local cursor_timer = 0

local ui = {}
-- #endregion setup

-- #region helpers misc
function dbg(...)
	unhooked.print(...)
end

function is_alt_key_down()
	return love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
end

function is_ctrl_key_down()
	return love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
end

function is_shift_key_down()
	return love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
end

function encode_key(key)
	local key_encoded = ""

	key_encoded = key_encoded .. (is_ctrl_key_down() and "^" or "")
	key_encoded = key_encoded .. (is_shift_key_down() and "+" or "")
	key_encoded = key_encoded .. (is_alt_key_down() and "%" or "")

	return key_encoded .. key
end
-- #endregion helpers

-- #region cursor
function reset_cursor_blink()
	cursor_timer = 0
	ui.cursor.visible = true
end

function update_cursor()
	local x = 4 + font_w + cursor_idx * font_w

	reset_cursor_blink()
	ui.cursor.x = x
end

function move_cursor_right()
	if (ui.selected.visible == true) then
		move_cursor_to_position(math.max(selected_idx1, selected_idx2))
		deselect_all()
		return
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	update_cursor()
end

function move_cursor_left()
	if (ui.selected.visible == true) then
		move_cursor_to_position(math.min(selected_idx1, selected_idx2))
		deselect_all()
		return
	end

	cursor_idx = math.max(0, cursor_idx - 1)
	update_cursor()
end

function move_cursor_to_position(pos)
	cursor_idx = util.clamp(pos, 0, utf8.len(input_buffer))
	update_cursor()
end

function move_cursor_by_offset(offset)
	cursor_idx = util.clamp(cursor_idx + offset, 0, utf8.len(input_buffer))
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
	if (string.match(utf8.sub(input_buffer, cursor_idx, cursor_idx), "[%s%p]") ~= nil) then
		cursor_idx = math.max(0, cursor_idx - 1)
	else
		local p_idx

		for i = cursor_idx - 1, 0, -1 do
			if (string.match(utf8.sub(input_buffer, i, i), "[%s%p]") ~= nil) then
				p_idx = i
				break
			end
		end

		cursor_idx = p_idx or 0
	end

	update_cursor()
end

function jump_cursor_right()
	if (string.match(utf8.sub(input_buffer, cursor_idx + 1, cursor_idx + 1), "[%s%p]") ~= nil) then
		cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	else
		local p_idx

		for i = cursor_idx, utf8.len(input_buffer) do
			if (string.match(utf8.sub(input_buffer, i + 1, i + 1), "[%s%p]") ~= nil) then
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

	if (ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = math.min(cursor_idx + 1, utf8.len(input_buffer))
	selected_idx2 = cursor_idx
	update_cursor()
	update_selected()
end

function select_cursor_left()
	if (cursor_idx == 0) then return end

	if (ui.selected.visible == false) then
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

	if (ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = 0
	selected_idx2 = cursor_idx
	update_selected()
	update_cursor()
end

function select_end()
	if (cursor_idx == utf8.len(input_buffer)) then return end

	if (ui.selected.visible == false) then
		selected_idx1 = cursor_idx
	end

	cursor_idx = utf8.len(input_buffer)
	selected_idx2 = cursor_idx
	update_selected()
	update_cursor()
end

function select_jump_cursor_left()
	if (cursor_idx == 0) then return end

	if (ui.selected.visible == false) then
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

	if (ui.selected.visible == false) then
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
	if (ui.selected.visible == true) then
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
	if (ui.selected.visible == true) then
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
	if (ui.selected.visible == true) then
		remove_selected()
	else
		if (cursor_idx == utf8.len(input_buffer)) then return end

		local left = utf8.sub(input_buffer, 1, cursor_idx)
		local right = utf8.sub(input_buffer, cursor_idx + 2, utf8.len(input_buffer))

		input_buffer =  left .. right
	end
end

function cut()
	if (ui.selected.visible == true) then
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
	if (ui.selected.visible == true) then
		local left_idx = math.min(selected_idx1, selected_idx2)
		local right_idx = math.max(selected_idx1, selected_idx2)

		love.system.setClipboardText(utf8.sub(input_buffer, left_idx + 1, right_idx))
	end
end

function paste()
	if (ui.selected.visible == true) then
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

	msg = parse.color(table.concat(arg, " "))
	table.insert(output_buffer, msg)
end

function clear_output_history()
	output_buffer = {}
	output_idx = 0
end

function move_output_by(n)
	output_idx = util.clamp(output_idx + n, 0, math.max(#output_buffer - num_output_buffer_lines, 0))
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
	hide()
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
	if (ui.selected.visible == true) then
		deselect_all()
	else
		clear_input_buffer()
	end
end

local changable_settings = {
	["background_color"] = {util.to_rgb_table, util.to_hex_string},
	["selected_color"] = {util.to_rgb_table, util.to_hex_string},
	["cursor_block_color"] = {util.to_rgb_table, util.to_hex_string},
	["cursor_line_color"] = {util.to_rgb_table, util.to_hex_string},
	["cursor_style"] = true,
	["cursor_blink_duration"] = true,
	["output_jump_by"] = true,
	["toggle_key"] = true,
	["color_info"] = true,
	["color_warn"] = true,
	["color_err"] = true,
	["color_com"] = true,
	["scroll_output_on_exec"] = true,
	["expose_output_functions"] = true
}

function list()
	for setting, _ in pairs(changable_settings) do
		local value = console[setting]

		if (type(value) == "table") then
			print(setting, " -> ", changable_settings[setting][2](value))
		else
			print(setting, " -> ", value)
		end
	end
end

function set(command)
	local parsed_command = parse.command(command)
	local setting = parsed_command[2]
	local value = parsed_command[3]

	if (changable_settings[setting] == true) then
		console[setting] = value
	elseif (type(changable_settings[setting]) == "table") then
		console[setting] = changable_settings[setting][1](value)
	end

	update_ui(love.graphics.getWidth(), love.graphics.getHeight())
end

local commands = {
	["$git"] = git,
	["$clear"] = clear,
	["$exit"] = exit,
	["$list"] = list,
	["$set"] = set
}

function exec_input_buffer()
	if (input_buffer == "") then return end
	if (input_buffer == "qqq") then quit() end

	if (scroll_output_on_exec == true) then
		output_idx = 0
	end

	add_to_history(input_buffer)
	add_to_output("|c" .. color_com .. ">|r" .. input_buffer)

	if (utf8.sub(input_buffer, 1, 1) == "$") then
		local space_idx = utf8.find(input_buffer, " ")
		local offset = space_idx and space_idx - 1 or nil
		local command = utf8.sub(input_buffer, 1, offset)

		if (commands[command] ~= nil) then
			commands[command](input_buffer)
		end
	else
		local func, err = loadstring(input_buffer)

		if (err ~= nil) then
			print(parse.repl(input_buffer))

		else
			local status, err = pcall(func)

			if (err ~= nil) then
				print("pcall: " .. err)
			end
		end
	end

	clear_input_buffer()
	deselect_all()
end
-- #endregion special commands

function warn(...)
	add_to_output("|c" .. color_warn .. "warning:|r", ...)
end

function err(...)
	add_to_output("|c" .. color_err .. "error:|r", ...)
end

function info(...)
	add_to_output("|c" .. color_info .. "info:|r", ...)
end

function cprint(color, ...)
	assert(string.len(color) == 6)
	unhooked.print(...)
	add_to_output("|c" .. color .. "ff" .. ... .. "|r")
end

-- #region global functions
if (expose_output_functions == true) then
	_G.warn = warn
	_G.err = err
	_G.info = info
	_G.cprint = cprint
end
-- #endregion global functions

function show()
	if (is_open == true) then return end

	is_open = true
	update_ui(love.graphics.getWidth(), love.graphics.getHeight())
	move_cursor_right()
	reset_cursor_blink()
	hook()
end

function hide()
	if (is_open == false) then return end

	is_open = false
	unhook()
end

-- #region keybinds
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
-- #endregion keybinds

-- #region ui
function toggle(key)
	if (key == toggle_key and is_open == false) then
		show()
	elseif (key == toggle_key and is_open == true) then
		hide()
	end
end

function update_ui(w, h)
	local left_pad = font_w / 2
	local bottom_pad = font_h + 4

	ui.background = {x = 0, y = 0, w = w, h = h / 3, color = background_color}

	local bottom_line_offset = ui.background.h - bottom_pad

	ui.arrow = {x = left_pad, y = bottom_line_offset}
	ui.input_line = {x = left_pad + font_w, y = bottom_line_offset}

	ui.output = {}
	local height_left = ui.background.h - font_h
	local i = 0

	while (height_left >= font_h) do
		i = i + 1
		ui.output[i] = {x = left_pad, y = bottom_line_offset - i * font_h}
		height_left = height_left - font_h
	end

	num_output_buffer_lines = i

	ui.selected = {x = left_pad + font_w, y = bottom_line_offset, w = 0, h = font_h, color = selected_color, visible = false}
	ui.cursor_counter = {x = w - 16 * font_w, y = ui.background.h - 4}

	if (cursor_style == "block") then
		ui.cursor = {x = left_pad + font_w, y = bottom_line_offset, w = font_w, h = font_h, color = cursor_block_color, visible = true}
	elseif (cursor_style == "line") then
		ui.cursor = {x = left_pad + font_w, y = bottom_line_offset, w = 1, h = font_h, color = cursor_line_color, visible = true}
	else
		assert(false, 'suported cursor styles: "block" or "line"')
	end
end

function draw_ui()
	love.graphics.setColor(ui.background.color)
	love.graphics.rectangle("fill", ui.background.x, ui.background.y, ui.background.w, ui.background.h + font_h)

	love.graphics.setColor(util.to_rgb_table("#FFFFFFFF"))
	love.graphics.print(">", ui.arrow.x, ui.arrow.y)
	love.graphics.print(input_buffer or "", ui.input_line.x, ui.input_line.y)
	love.graphics.print("C: " .. cursor_idx .. " L: 0", ui.cursor_counter.x, ui.cursor_counter.y)

	for i = 1, num_output_buffer_lines do
		local idx = #output_buffer - i + 1

		love.graphics.print(output_buffer[idx - output_idx] or "", ui.output[i].x, ui.output[i].y)
	end

	if (ui.selected.visible == true) then
		love.graphics.setColor(ui.selected.color)
		love.graphics.rectangle("fill", ui.selected.x, ui.selected.y, ui.selected.w, ui.selected.h)
	end

	if (ui.cursor.visible == true) then
		love.graphics.setColor(ui.cursor.color)
		love.graphics.rectangle("fill", ui.cursor.x, ui.cursor.y, ui.cursor.w, ui.cursor.h)
	end
end
-- #endregion ui

-- #region hooks and overrides
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

function console_update(dt)
	if (unhooked.update ~= nil) then
		unhooked.update(dt)
	end

	cursor_timer = cursor_timer + dt

	if (cursor_timer >= cursor_blink_duration) then
		ui.cursor.visible = not ui.cursor.visible
		cursor_timer = cursor_timer - cursor_blink_duration
	end
end

function console_draw()
	if (unhooked.draw ~= nil) then
		love.graphics.setFont(unhooked.font)
		love.graphics.setColor(unhooked.color)
		unhooked.draw()
		love.graphics.setFont(font)
	end

	draw_ui()
end

function console_resize(w, h)
	if (unhooked.resize ~= nil) then
		unhooked.resize(w, h)
	end

	update_ui(w, h)
end

function console_wheelmoved(_, dir)
	move_output_by(dir)
end

function console_keypressed(key)
	local key_encoded = encode_key(key)

	if (keybinds[key_encoded] ~= nil) then
		keybinds[key_encoded]()
	end
end

function console_textinput(key)
	if (key == toggle_key) then
		toggle(key)
		return
	end
	inset_character(key)
end

function hook()
	unhooked.key_repeat = love.keyboard.hasKeyRepeat()
	unhooked.font = love.graphics.getFont()
	unhooked.color = {love.graphics.getColor()}

	unhooked.update = love.update
	unhooked.draw = love.draw
	unhooked.wheelmoved = love.wheelmoved
	unhooked.keypressed = love.keypressed
	unhooked.textinput = love.textinput
	unhooked.resize = love.resize

	love.keyboard.setKeyRepeat(true)
	love.graphics.setFont(font)

	love.update = console_update
	love.draw = console_draw
	love.resize = console_resize
	love.wheelmoved = console_wheelmoved
	love.keypressed = console_keypressed
	love.textinput = console_textinput
end

function unhook()
	love.keyboard.setKeyRepeat(unhooked.key_repeat)
	love.graphics.setFont(unhooked.font)
	love.graphics.setColor(unhooked.color)

	love.update = unhooked.update
	love.draw = unhooked.draw
	love.wheelmoved = unhooked.wheelmoved
	love.keypressed = unhooked.keypressed
	love.textinput = unhooked.textinput
	love.resize = unhooked.resize
end
-- #endregion hooks and overrides

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

hook_print()
hook_close()
add_to_output(git_link)
add_to_output("Press ` or type 'exit' to close")

return console.toggle
