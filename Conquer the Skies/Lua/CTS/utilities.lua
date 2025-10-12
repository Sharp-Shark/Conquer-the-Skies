-- Output table in a neat way
CTS.tablePrint = function (t, output, long, depth, chars, history)
	if t == nil then
		out = 'nil'
		if not output then print(out) end
		return out
	end
	
	-- avoids infinite recursion
	local historyCopy = {}
	for k, v in pairs(history or {}) do
		historyCopy[k] = v
	end
	local history = historyCopy
	history[t] = true
	
	local chars = chars or {}
	local quoteChar = chars['quote'] or '"'
	local lineChar = chars['line'] or '\n'
	local spaceChar = chars['space'] or '    '
	local depth = depth or 0
	local long = long or -1
	
	local out = '{'
	if long >= 0 then
		out = out .. lineChar
	else
		out = out .. ' '
	end
	local first = true
	for key, value in pairs(t) do
		if not first then
			if long >= 0 then
				out = out .. ',' .. lineChar
			else
				out = out .. ', '
			end
		else
			first = false
		end
		if long >= 0 then
			out = out .. string.rep(spaceChar, (depth + 1) * long)
		end
		if type(key) == 'function' then
			out = out .. 'FUNCTION'
		elseif type(key) == 'boolean' then
			if key then
				out = out .. 'true'
			else
				out = out .. 'false'
			end
		elseif type(key) == 'userdata' then
			if not pcall(function ()
				out = out .. 'UD:' ..key.Name
			end) then
				if not pcall(function ()
					out = out .. key.Info.Name
				end) then
					out = out .. 'USERDATA'
				end
			end
		elseif type(key) == 'table' then
			if history[key] then
				out = out + 'RECURSION'
			else
				out = out .. CTS.tablePrint(key, true, long, depth + 1, chars, history)
			end
		elseif type(key) == 'string' then
			out = out .. quoteChar .. key .. quoteChar
		else
			out = out .. key
		end
		out = out .. ' = '
		if type(value) == 'function' then
			out = out .. 'FUNCTION'
		elseif type(value) == 'boolean' then
			if value then
				out = out .. 'true'
			else
				out = out .. 'false'
			end
		elseif type(value) == 'userdata' then
			if not pcall(function ()
				out = out .. 'UD:' ..value.Name
			end) then
				if not pcall(function ()
					out = out .. value.Info.Name
				end) then
					out = out .. 'USERDATA'
				end
			end
		elseif type(value) == 'table' then
			if history[value] then
				out = out .. 'RECURSION'
			else
				out = out .. CTS.tablePrint(value, true, long, depth + 1, chars, history)
			end
		elseif type(value) == 'string' then
			out = out .. quoteChar .. value .. quoteChar
		else
			out = out .. value
		end
	end
	if long >= 0 then
		out = out .. lineChar .. string.rep(spaceChar, depth * long) .. '}'
	else
		out = out .. ' }'
	end
	if not output then print(out) end
	return out
end