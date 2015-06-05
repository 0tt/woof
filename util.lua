function table.exists(t, val)
	assert(type(t)=="table", "bad argument #1 to table.exists (table expected, got " .. type(t) .. ")")
	for k, v in pairs(t) do
		if v == val then return k, v end
	end
end
function table.print(t)
	assert(type(t)=="table", "bad argument #1 to table.print (table expected, got " .. type(t) .. ")")
	local done = {t}
	local ret = ""
	local function pt(t, indent)
		local keys = {}
		for k in pairs(t) do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			if type(a) == "number" and type(b) == "number" then 
				return a < b 
			end
			return tostring(a) < tostring(b)
		end)
		for i = 1, #keys do
			if type(t[keys[i]])=="table" then
				if not table.exists(done, t[keys[i]]) then
					print(string.rep("\t", indent) .. tostring(keys[i]) .. ":")
					table.insert(done, t[keys[i]])
					pt(t[keys[i]], indent + 1)
				else
					print(string.rep("\t", indent) .. tostring(keys[i]) .. " = " .. tostring(t[keys[i]]))
				end
			else
				print(string.rep("\t", indent) .. tostring(keys[i]) .. " = " .. tostring(t[keys[i]]))
			end
		end
	end
	print("Table:")
	pt(t, 1)
end

function screenToWorld(x, y)
	return x - WIDTH / 2 - Camera.x * Camera.sx, -(y - HEIGHT / 2) - Camera.y * Camera.sy
end
function center(x1, y1, x2, y2)
	return (x1 + x2) / 2, (y1 + y2) / 2
end
function distance(x1, y1, x2, y2)
	return math.sqrt((y2 - y1)^2 + (x2 - x1)^2)
end
function lerp(from, to, t)
	return from + (t * (to - from))
end