local utf8 = require(console.path_req .. ".utf8")
local repl = {}


function repl.parse(msg)
	local queue = {}
	local enqueue = function(v)	table.insert(queue, v) end
	local dequeue = function() local v = queue[1] table.remove(queue, 1) return v end
	local num_loops = 0

	while (msg ~= "") do
		if (num_loops >= 15) then
			err("Something went horribly wrong (either the parser failed somehow")
			err("or the variable is nested too deep, >= 15), please report this")
			return nil
		end

		local dot_idx = utf8.find(msg, "%.") or math.huge
		local bra_idx = utf8.find(msg, "%[") or math.huge
		local first_idx = math.min(dot_idx, bra_idx)

		if (dot_idx == 1) then
			msg = utf8.sub(msg, 2)
		elseif (bra_idx == 1) then
			local end_idx = utf8.find(msg, "%]")
			if (utf8.sub(msg, 2, 2) == "\"") then
				enqueue(utf8.sub(msg, 3, end_idx - 2))
			else
				enqueue(tonumber(utf8.sub(msg, 2, end_idx - 1)))
			end
			msg = utf8.sub(msg, end_idx + 1)
		else
			enqueue(utf8.sub(msg, 1, first_idx - 1))
			msg = utf8.sub(msg, first_idx)
		end

		num_loops = num_loops + 1
	end

	local value

	while (#queue > 0) do
		local t = dequeue()

		if (value == nil) then
			value = _G[t]
		else
			if (type(value) == "table" and value[t] ~= nil) then
				value = value[t]
			else
				value =  nil
			end
		end
	end

	return tostring(value)
end

return repl
