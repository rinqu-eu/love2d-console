local path = ...
local path_req = path:sub(1, -7)
local utf8 = require(path_req .. ".utf8")
local color = {}

function color.to_RGB(hex_string)
	local len  = hex_string:len()
	assert(len == 7 or len == 9, "hex string expected, #rrggbb or #rrggbbaa")

	local r = tonumber(hex_string:sub(2, 3), 16) / 255
	local g = tonumber(hex_string:sub(4, 5), 16) / 255
	local b = tonumber(hex_string:sub(6, 7), 16) / 255
	local a

	if (len == 9) then
		a = tonumber(hex_string:sub(8, 9), 16) / 255
	end

	return {r, g, b, a}
end

local function new_stack()
	local push = function(self, color) table.insert(self, color) end
	local pop = function (self) if (#self > 0) then table.remove(self, #self) end end
	local peek = function (self) if (#self > 0) then return self[#self] end end

	return {push = push, pop = pop, peek = peek}
end

-- NOTE (rinqu):
-- the reason why parsed_message looks like it does is because I'm using
-- functionality of love.graphics.print to handle color printing for me

-- raw_message		-> standard string passed to the parser
-- parsed_message	-> table containing fragments
-- fragment			-> 2 entries in the table that need to be one after the other
--					   1st entry is a table containing a rgb color values between 0-1
--					   2nd entry is the message text

local color_tag_open = "|c%x%x%x%x%x%x%x%x"
local color_tag_open_len = 10
local color_tag_close = "|r"
local color_tag_close_len = 2

function color.parse(raw_message)
	local parsed_message = {}
	local color_stack = new_stack()
	local offset_into_raw_message = 1
	local raw_message_length = utf8.len(raw_message)

	while (offset_into_raw_message <= raw_message_length) do
		local remaining_raw_message = utf8.sub(raw_message, offset_into_raw_message)
		local color_tag_open_idx = utf8.find(remaining_raw_message, color_tag_open)
		local color_tag_close_idx = utf8.find(remaining_raw_message, color_tag_close)

		-- we are at an open tag, extract the color
		if (color_tag_open_idx == 1) then
			local color = utf8.sub(remaining_raw_message, color_tag_open_idx + 2, color_tag_open_idx + 9)

			color_stack:push("#" .. color)
			offset_into_raw_message = offset_into_raw_message + color_tag_open_len
		-- we are at a close tag
		elseif (color_tag_close_idx == 1) then
			color_stack:pop()
			offset_into_raw_message = offset_into_raw_message + color_tag_close_len
		-- we have a normal string in in front of us
		-- find out how long it is and push it as a fragment together with its color
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

local function print_parsed_message(parsed_message)
	assert(#parsed_message % 2 == 0, "number of elements in the parsed message has to be even")
	local fragment_count = #parsed_message / 2

	for i = 1, fragment_count do
		local offset = i * 2 - 1
		local fragment_color = parsed_message[offset]
		local fragment_message = parsed_message[offset+1]

		fragment_color[1] = string.format("r: %#.2f", fragment_color[1])
		fragment_color[2] = string.format("g: %#.2f", fragment_color[2])
		fragment_color[3] = string.format("b: %#.2f", fragment_color[3])
		fragment_color[4] = string.format("a: %#.2f", fragment_color[4])

		fragment_color = "color: " .. table.concat(fragment_color, " ") .. "\t"
		fragment_message = "text: _" .. fragment_message .. "_"

		print(fragment_color, fragment_message)
	end

end

local function compare_parsed_messages(description, parsed_message_1, parsed_message_2)
	print(description)
	-- print(#parsed_message_1)
	-- print(#parsed_message_2)
	assert(#parsed_message_1 == #parsed_message_2)
	for i = 1, #parsed_message_1 do
		if (type(parsed_message_1[i]) == "table") then
			assert(parsed_message_1[i][1] == parsed_message_2[i][1], description .. ": r doesn't match")
			assert(parsed_message_1[i][2] == parsed_message_2[i][2], description .. ": g doesn't match")
			assert(parsed_message_1[i][3] == parsed_message_2[i][3], description .. ": b doesn't match")
			assert(parsed_message_1[i][4] == parsed_message_2[i][4], description .. ": a doesn't match")
		else
			assert(parsed_message_1[i] == parsed_message_2[i], description .. ": text doesn't match")
		end
	end
end

local function run_tests()
	compare_parsed_messages("empty raw message", color.parse(""), {{1, 1, 1, 1}, ""})
	compare_parsed_messages("raw message with no color tag", color.parse("test string"), {{1, 1, 1, 1}, "test string"})
	compare_parsed_messages("raw message with no color close tag", color.parse("|cff0000fftest string"), {{1, 0, 0, 1}, "test string"})
	compare_parsed_messages("raw message with no color open tag", color.parse("test string|r"), {{1, 1, 1, 1}, "test string"})
	compare_parsed_messages("raw message with 2 color open tag", color.parse("|cff0000fftest   |c00ff00ffstring"), {{1, 0, 0, 1}, "test   ", {0, 1, 0, 1}, "string"})
	compare_parsed_messages("raw message with 2 color open tag, 1 close tag", color.parse("|cff0000fftest   |c00ff00ffstring|r   t"), {{1, 0, 0, 1}, "test   ", {0, 1, 0, 1}, "string", {1, 0, 0, 1}, "   t"})
	print("color.parse -> all test passed")
end


run_tests()

return color
