local path = ...
local path_req = path:sub(1, -7)

local utf8 = require(path_req .. ".utf8")
local util = require(path_req .. ".util")

local parse = {}

local function stack()
	local push = function(self, element) table.insert(self, element) end
	local pop = function (self) if (#self > 0) then return table.remove(self, #self) end end
	local peek = function (self) if (#self > 0) then return self[#self] end end

	return {push = push, pop = pop, peek = peek}
end

local function queue()
	local enqueue = function(self, element) table.insert(self, element) end
	local dequeue = function(self) if (#self > 0) then return table.remove(self, 1) end end
	local peek = function(self) if (#self > 0) then return self[1] end end

	return {enqueue = enqueue, dequeue = dequeue, peek = peek}
end

function parse.repl(msg)
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

local color_tag_open = "|c%x%x%x%x%x%x%x%x"
local color_tag_open_len = 10
local color_tag_close = "|r"
local color_tag_close_len = 2

-- NOTE (rinqu): the reason why parsed_message looks like it does is because I'm using the functionality of love.graphics.print to handle color printing for me
function parse.color(raw_message)
	local parsed_message = {}
	local color_stack = stack()
	local offset_into_raw_message = 1
	local raw_message_length = utf8.len(raw_message)

	while (offset_into_raw_message <= raw_message_length) do
		local remaining_raw_message = utf8.sub(raw_message, offset_into_raw_message)
		local color_tag_open_idx = utf8.find(remaining_raw_message, color_tag_open)
		local color_tag_close_idx = utf8.find(remaining_raw_message, color_tag_close)

		if (color_tag_open_idx == 1) then
			local color = utf8.sub(remaining_raw_message, color_tag_open_idx + 2, color_tag_open_idx + 9)

			color_stack:push("#" .. color)
			offset_into_raw_message = offset_into_raw_message + color_tag_open_len
		elseif (color_tag_close_idx == 1) then
			color_stack:pop()
			offset_into_raw_message = offset_into_raw_message + color_tag_close_len
		else
			local next_color_tag_idx = (color_tag_open_idx or color_tag_close_idx) and math.min(color_tag_open_idx or math.huge, color_tag_close_idx or math.huge) or 0
			local color_ = util.to_RGB_table(color_stack:peek() or "#ffffffff")
			local text = utf8.sub(remaining_raw_message, 1, next_color_tag_idx - 1) or ""

			table.insert(parsed_message, color_)
			table.insert(parsed_message, text)

			offset_into_raw_message = offset_into_raw_message + utf8.len(text)
		end
	end

	if (#parsed_message == 0) then
		table.insert(parsed_message, util.to_RGB_table("#ffffffff"))
		table.insert(parsed_message, "")
	end

	return parsed_message
end

return parse
