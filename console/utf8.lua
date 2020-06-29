local utf8 = require("utf8")

-- NOTE (rinqu): this is a basic implementation
function utf8.sub(s, i, j)
	assert(type(s) == "number" or type(s) == "string", string.format("bad argument #1 to 'sub' (string expected, got %s)", type(s) ~= "nil" and type(s) or "no value"))
	assert(type(i) == "number" or type(tonumber(i)) == "number", string.format("bad argument #2 to 'sub' (number expected, got %s)", type(i) ~= "nil" and type(i) or "no value"))
	assert(type(j) == "nil" or type(j) == "number" or type(tonumber(j) == "number"), string.format("bad argument #3 to 'sub' (number expeted, got %s)",	type(i)))

	s, i, j = tostring(s), tonumber(i), tonumber(j)

	local offset_i, offset_j
	local s_len = utf8.len(s)

	if (i > s_len) then
		offset_i = utf8.offset(s, s_len + 1)
	elseif (i < -s_len) then
		offset_i = 0
	else
		offset_i = utf8.offset(s, i)
	end

	if (j ~= nil) then
		if (j > s_len or j == -1) then
			offset_j = utf8.offset(s, s_len + 1) - 1
		elseif (j < -s_len) then
			offset_j = 0
		else
			offset_j = utf8.offset(s, j + 1) - 1
		end
	end

	return string.sub(s, offset_i, offset_j)
end

-- NOTE (rinqu): this is a basic implementation
function utf8.find(s, pattern, index)
	assert(type(s) == "number" or type(s) == "string", string.format("bad argument #1 to 'find' (string expected, got %s)", type(s) ~= "nil" and type(s) or "no value"))
	assert(type(pattern) == "number" or type(pattern) == "string", string.format("bad argument #2 to 'find' (string expected, got %s)", type(pattern) ~= "nil" and type(pattern) or "no value"))

	s, pattern, index = tostring(s), tostring(pattern), index or 1

	local function depattern(pattern) local tp = {"%%x", "%%.", "%%[", "%%]"} local td = {"x", ".", "[", "]"} local p = pattern for i, v in pairs(tp) do pattern = string.gsub(pattern, v, td[i]) end return pattern end
	local s_len = utf8.len(s)
	local p_len = string.len(depattern(pattern))

	for i = index, s_len do
		local s_ = utf8.sub(s, i, i + p_len - 1)

		if (string.find(s_, pattern) ~= nil) then
			return i, i + p_len - 1
		end
	end

	return nil
end

return utf8
