local utf8 = require(console.path_req .. ".utf8")
local color = {}

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

return color
