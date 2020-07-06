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

function color.parse(text)
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
	compare_parsed_messages("raw message with no color close tag", color.parse("|cffff0000test string"), {{1, 0, 0, 1}, "test string"})
	compare_parsed_messages("raw message with no color open tag", color.parse("test string|r"), {{1, 1, 1, 1}, "test string"})
	compare_parsed_messages("raw message with 2 color open tag", color.parse("|cffff0000test   |cff00ff00string"), {{1, 0, 0, 1}, "test   ", {0, 1, 0, 1}, "string"})
	compare_parsed_messages("raw message with 2 color open tag, 1 close tag", color.parse("|cffff0000test   |cff00ff00string|r   t"), {{1, 0, 0, 1}, "test   ", {0, 1, 0, 1}, "string", {1, 0, 0, 1}, "   t"})
	print("color.parse -> all test passed")
end

-- run_tests()

return color
