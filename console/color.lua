local path = ...
local path_req = path:sub(1, -7)

local utf8 = require(path_req .. ".utf8")
local util = require(path_req .. ".util")

local color = {}

local function stack()
	local push = function(self, color) table.insert(self, color) end
	local pop = function (self) if (#self > 0) then table.remove(self, #self) end end
	local peek = function (self) if (#self > 0) then return self[#self] end end

	return {push = push, pop = pop, peek = peek}
end

local color_tag_open = "|c%x%x%x%x%x%x%x%x"
local color_tag_open_len = 10
local color_tag_close = "|r"
local color_tag_close_len = 2

-- NOTE (rinqu): the reason why parsed_message looks like it does is because I'm using the functionality of love.graphics.print to handle color printing for me
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

return color
