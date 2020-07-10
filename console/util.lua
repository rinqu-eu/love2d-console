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

function util.is_valid_hex_string(hex_string)
	if (type(hex_string) ~= "string") then
		return false, "arg #1 -> string expected, got _" .. type(hex_string) .. "_"
	end

	local len = string.len(hex_string)

	if (len ~= 7 and len ~= 9) then
		return false, "arg #1 -> length 7 or 9 expected, got _" .. len .. "_"
	end

	if ((len == 7 and string.find(hex_string, "#%x%x%x%x%x%x") == nil) or
		(len == 9 and string.find(hex_string, "#%x%x%x%x%x%x%x%x") == nil)) then
		return false, "arg #1 -> value in format #rrggbb or #rrggbbaa expected, got _" .. hex_string .. "_"
	end

	return true
end

function util.is_valid_rgb_table(rgb_table)
	if (type(rgb_table) ~= "table") then
		return false, "arg #1 -> table expected, got _" .. type(rgb_table) .. "_"
	end

	local len = #rgb_table

	if (len < 3 or len > 4) then
		return false, "arg #1 -> length 3 or 4 expected, got _" .. len .. "_"
	end

	for i = 1, len do
		if (type(rgb_table[i]) ~= "number") then
			return false, "arg #1[" .. i .. "] -> number expected, got _" .. type(rgb_table[i]) .. "_"
		end

		if (rgb_table[i] > 1 or rgb_table[i] < 0) then
			return false, "arg #1[" .. i .. "] -> value between 0 and 1 expected, got _" .. rgb_table[i] .. "_"
		end
	end

	return true
end

function util.to_rgb_table(hex_string)
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

function util.to_hex_string(rgb_table)
	assert(type(rgb_table) == "table", "arg #1 table expected, got " .. type(rgb_table))
	assert(#rgb_table == 3 or #rgb_table == 4, "arg #1 RGB table expected, got _" .. #rgb_table .. "_")

	local r = string.format("%02x", util.clamp(rgb_table[1], 0, 1) * 255)
	local b = string.format("%02x", util.clamp(rgb_table[2], 0, 1) * 255)
	local g = string.format("%02x", util.clamp(rgb_table[3], 0, 1) * 255)
	local a = ""

	if (#rgb_table == 4) then
		a = string.format("%02x", util.clamp(rgb_table[4], 0, 1) * 255)
	end

	return "#" .. r .. g .. b .. a
end

return util
