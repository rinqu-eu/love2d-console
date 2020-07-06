local path = ...
local path_req = path:sub(1, -7)
local utf8 = require(path_req .. ".utf8")
local color = {}

function color.to_RGB(hex_string)
	local len = hex_string:len()
	assert(len == 7 or len == 9, "hex string expected, #rrggbb or #rrggbbaa")

	local r = tonumber(hex_string:sub(2, 3), 16) / 255
	local g = tonumber(hex_string:sub(4, 5), 16) / 255
	local b = tonumber(hex_string:sub(6, 7), 16) / 255
	local a = 1.0

	if (len == 9) then
		a = tonumber(hex_string:sub(8, 9), 16) / 255
	end

	return {r, g, b, a}
end

local function stack()
	local push = function(self, color) table.insert(self, color) end
	local pop = function (self) if (#self > 0) then table.remove(self, #self) end end
	local peek = function (self) if (#self > 0) then return self[#self] end end

	return {push = push, pop = pop, peek = peek}
end

-- NOTE (rinqu): the reason why parsed_message looks like it does is because I'm using functionality of love.graphics.print to handle color printing for me

local color_tag_open = "|c%x%x%x%x%x%x%x%x"
local color_tag_open_len = 10
local color_tag_close = "|r"
local color_tag_close_len = 2

function color.parse(raw_message)
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
			local color_ = color.to_RGB(color_stack:peek() or "#ffffffff")
			local text = utf8.sub(remaining_raw_message, 1, next_color_tag_idx - 1) or ""

			table.insert(parsed_message, color_)
			table.insert(parsed_message, text)

			offset_into_raw_message = offset_into_raw_message + utf8.len(text)
		end
	end

	if (#parsed_message == 0) then
		table.insert(parsed_message, color.to_RGB("#ffffffff"))
		table.insert(parsed_message, "")
	end

	return parsed_message
end

return color
