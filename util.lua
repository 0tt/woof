function table.exists(t, val)
	assert(type(t)=="table", "wrong fucking type, asshole")
	for k, v in pairs(t) do
		if v == val then return k, v end
	end
end
function table.print(t)
	assert(type(t)=="table", "wrong fucking type, dickhead (" .. type(t) .. ")")
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