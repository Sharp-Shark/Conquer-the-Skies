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

-- Find waypoints by job
CTS.findWaypointsByJob = function (submarine, job)
	local waypoints = {}
	for waypoint in submarine.GetWaypoints(false) do
		if (waypoint.AssignedJob ~= nil) and (waypoint.AssignedJob.Identifier == job) then
			table.insert(waypoints, waypoint)
		end
	end
	if (job == '') and (#waypoints < 1) then
		for waypoint in submarine.GetWaypoints(false) do
			if waypoint.SpawnType == SpawnType.Human then
				table.insert(waypoints, waypoint)
			end
		end
		
	end
	return waypoints
end

-- Find one random waypoint of a job
CTS.findRandomWaypointByJob = function (submarine, job)
	local waypoints = CTS.findWaypointsByJob(submarine, job)
	return waypoints[math.random(#waypoints)]
end

-- Flip submarine X
CTS.flipSubmarine = function (submarine, flipCharacters)
    submarine.FlipX()
    if flipCharacters then
        for character in Character.CharacterList do
            if character.Submarine == submarine then
                local offsetX = character.WorldPosition.X - submarine.WorldPosition.X
                character.TeleportTo(Vector2(submarine.WorldPosition.X - offsetX, character.WorldPosition.Y))
            end
        end
    end
    if SERVER then
        local message = Networking.Start("syncsubflippedx")
        message.WriteUInt16(submarine.ID)
        message.WriteBoolean(submarine.FlippedX)
        Networking.Send(message)
    end
end

-- used for posing NPCs
CTS.freezeCharacter = function (character, bool)
	local value = 0
	if bool then value = 2 end
	
	character.AnimController.Collider.BodyType = value
	for limb in character.AnimController.Limbs do
		limb.body.BodyType = value
	end
	
	print(character, ' state: ', value)
end