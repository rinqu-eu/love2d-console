local math = require("math")

function math.clamp(min, value, max)
	if (value > max) then
		return max
	elseif (value < min) then
		return min
	else
		return value
	end
end

return math
