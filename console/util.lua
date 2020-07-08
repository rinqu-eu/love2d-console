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

return util
