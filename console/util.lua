local util = {}

function util.clamp(value, min, max)
	assert(type(value) == "number", "arg #1 number expected, got " .. type(value))
	assert(type(min) == "number", "arg #2 number expected, got " .. type(min))
	assert(type(max) == "number", "arg #3 number expected, got " .. type(max))

	if (value > max) then
		return max
	elseif (value < min) then
		return min
	end

	return value
end

function util.to_RGB_table(hex_string)
	assert(type(hex_string) == "string", "arg #1 string expected, got " .. type(hex_string))
	assert(hex_string:len() == 7 or hex_string:len() == 9, "arg #1 hex string expected, got _" .. hex_string .. "_")
	assert(hex_string:find("#%x%x%x%x%x%x") ~= nil or hex_string:find("#%x%x%x%x%x%x%x%x") ~= nil, "arg #1 hex string expected, got _" .. hex_string .. "_")

	local r = tonumber(hex_string:sub(2, 3), 16) / 255
	local g = tonumber(hex_string:sub(4, 5), 16) / 255
	local b = tonumber(hex_string:sub(6, 7), 16) / 255
	local a

	if (hex_string:len() == 9) then
		a = tonumber(hex_string:sub(8, 9), 16) / 255
	end

	return {r, g, b, a}
end

function util.to_hex_string(RGB_table)
	assert(type(RGB_table) == "table", "arg #1 table expected, got " .. type(RGB_table))
	assert(#RGB_table == 3 or #RGB_table == 4, "arg #1 RGB table expected, got _" .. #RGB_table .. "_")

	local r = string.format("%02x", util.clamp(RGB_table[1], 0, 1) * 255)
	local b = string.format("%02x", util.clamp(RGB_table[2], 0, 1) * 255)
	local g = string.format("%02x", util.clamp(RGB_table[3], 0, 1) * 255)
	local a = ""

	if (#RGB_table == 4) then
		a = string.format("%02x", util.clamp(RGB_table[4], 0, 1) * 255)
	end

	return "#" .. r .. g .. b .. a
end

return util
