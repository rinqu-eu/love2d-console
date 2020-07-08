local util = {}

function util.clamp(min, value, max)
	if (value > max) then
		return max
	elseif (value < min) then
		return min
	else
		return value
	end
end

function util.to_RGB_table(hex_string)
	assert(type(hex_string) == "string", "arg #1 string expected, got " .. type(hex_string))
	assert(hex_string:len() == 7 or hex_string:len() == 9, "arg #1 hex string expected, got _" .. hex_string .. "_")
	assert(string.find(hex_string, "#%x%x%x%x%x%x") ~= nil or string.find(hex_string, "#%x%x%x%x%x%x%x%x") ~= nil, "arg #1 hex string expected, got _" .. hex_string .. "_")

	local r = tonumber(hex_string:sub(2, 3), 16) / 255
	local g = tonumber(hex_string:sub(4, 5), 16) / 255
	local b = tonumber(hex_string:sub(6, 7), 16) / 255
	local a = 1.0

	if (len == 9) then
		a = tonumber(hex_string:sub(8, 9), 16) / 255
	end

	return {r, g, b, a}
end

return util
