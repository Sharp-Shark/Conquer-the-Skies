-- submarinebuilder.lua taken from TraitorMod by Evil Factory

--Game.OverrideRespawnSub(true) -- remove respawn submarine logic

local sb = {}

local linkedSubmarineHeader = [[<LinkedSubmarine description="" checkval="2040186250" price="1000" initialsuppliesspawned="false" type="Player" tags="Shuttle" gameversion="0.17.4.0" dimensions="1270,451" cargocapacity="0" recommendedcrewsizemin="1" recommendedcrewsizemax="2" recommendedcrewexperience="Unknown" requiredcontentpackages="Vanilla" name="%s" filepath="Content/Submarines/Selkie.sub" pos="-64,-392.5" linkedto="4" originallinkedto="0" originalmyport="0">%s</LinkedSubmarine>]]

-- Find waypoints by job
local tableSize = function (t)
	local size = 0
	for item in t do size = size + 1 end
	return size
end

local findWaypointsByJob = function (submarine, job)
	local waypoints = {}
	for waypoint in submarine.GetWaypoints(false) do
		if (waypoint.AssignedJob ~= nil) and (waypoint.AssignedJob.Identifier == job) then
			table.insert(waypoints, waypoint)
		end
	end
	if (job == '') and (tableSize(waypoints) < 1) then
		for waypoint in submarine.GetWaypoints(false) do
			if waypoint.SpawnType == SpawnType.Human then
				table.insert(waypoints, waypoint)
			end
		end
		
	end
	return waypoints
end

-- Find one random waypoint of a job
local findRandomWaypointByJob = function (submarine, job)
	local waypoints = findWaypointsByJob(submarine, job)
	return waypoints[math.random(#waypoints)]
end

sb.IsActive = function ()
    return Game.GetRespawnSub() ~= nil
end

sb.UpdateLobby = function(submarineInfo, team, clear)
    local submarines = Game.NetLobbyScreen.subs
	
	if clear then
		for key, value in pairs(submarines) do
			if value.Name == "submarineinjector" then
				table.remove(submarines, key)
			end
		end
	end
	
	if submarineInfo ~= nil then
		table.insert(submarines, submarineInfo)
		SubmarineInfo.AddToSavedSubs(submarineInfo)

		Game.NetLobbyScreen.subs = submarines
		if team == 1 then
			Game.NetLobbyScreen.SelectedSub = submarineInfo
		elseif team == 2 then
			Game.NetLobbyScreen.SelectedEnemySub = submarineInfo
		else
			Game.NetLobbyScreen.SelectedShuttle = submarineInfo
		end
	else
		Game.NetLobbyScreen.subs = submarines
	end

    for _, client in pairs(Client.ClientList) do
        client.InitialLobbyUpdateSent = false
        Networking.ClientWriteLobby(client)
    end
end

sb.Submarines = {}

sb.AddSubmarine = function (path, name, isTemporary, team)
    isTemporary = isTemporary or false

    local submarineInfo = SubmarineInfo(path)

    name = name or submarineInfo.Name

    local xml = tostring(submarineInfo.SubmarineElement)

    local _, endPos = string.find(xml, ">")
    local startPos, _ = string.find(xml, "</Submarine>")

    local data = string.sub(xml, endPos + 1, startPos - 1)

    table.insert(sb.Submarines, {Name = name, Data = data, IsTemporary = isTemporary, Team = team})

    return name
end

sb.FindSubmarine = function (name)
    for _, submarine in pairs(Submarine.Loaded) do
        if submarine.Info.Name == name then
            return submarine
        end
    end
end

sb.ResetSubmarineSteering = function (submarine)
    if submarine == nil then error("ResetSubmarineSteering: submarine was nil", 2) end
    for _, item in pairs(submarine.GetItems(true)) do
        local steering = item.GetComponentString("Steering")
        if steering then
            steering.AutoPilot = true
            steering.MaintainPos = true
            steering.PosToMaintain = submarine.WorldPosition
            steering.UnsentChanges = true
        end
    end
end

sb.BuildSubmarines = function(team)
    local submarineInjector = File.Read(FVF.path .. "/Submarines/submarineinjector.xml")
    local result = ""

    for k, v in pairs(sb.Submarines) do
		if v.Team == team then
			result = result .. string.format(linkedSubmarineHeader, v.Name, v.Data)
		end
    end

    local submarineText = string.format(submarineInjector, result)
	local submarineName = 'temp' .. tostring(team or 0)

    File.Write(FVF.path .. "/Submarines/temp.xml", submarineText)
    local submarineInfoXML = SubmarineInfo(FVF.path .. "/Submarines/temp.xml")
    submarineInfoXML.SaveAs(FVF.path .. "/Submarines/" .. submarineName .. ".sub")

    local submarineInfo = SubmarineInfo(FVF.path .. "/Submarines/" .. submarineName .. ".sub")

    sb.UpdateLobby(submarineInfo, team)
    return submarineInfo
end

sb.RoundStart = function ()
    if Submarine.MainSub == nil then return end
	
	-- enemy mainsub
	local enemyMainSub
	for submarine in Submarine.Loaded do
		if submarine.TeamID == CharacterTeamType.Team2 then
			enemyMainSub = submarine
			break
		end
	end
	
	-- undock
    for _, item in pairs(Submarine.MainSub.GetItems(false)) do
        local dockingPort = item.GetComponentString("DockingPort")
        if dockingPort then
            dockingPort.Undock()
        end
    end
    for _, item in pairs(enemyMainSub.GetItems(false)) do
        local dockingPort = item.GetComponentString("DockingPort")
        if dockingPort then
            dockingPort.Undock()
        end
    end
	
	-- moved characters
	local movedCharacterSet = {}
	local teamSubCount = {}
    for _, value in pairs(sb.Submarines) do
		if teamSubCount[value.Team] == nil then teamSubCount[value.Team] = 0 end
		local submarine = sb.FindSubmarine(value.Name)
		if submarine ~= nil then
			teamSubCount[value.Team] = teamSubCount[value.Team] + 1
		end
	end
	
	-- organize fleet
	local anchors = {[1] = Submarine.MainSub, [2] = enemyMainSub}
    for _, value in pairs(sb.Submarines) do
		local submarine = sb.FindSubmarine(value.Name)

		if submarine ~= nil then
			sb.MoveSubmarineToOther(submarine, anchors[value.Team])
			anchors[value.Team] = submarine
			
			sb.ResetSubmarineSteering(submarine)
			
			Timer.NextFrame(function ()
				for item in submarine.GetItems(true) do
					item.FindHull()
				end
			end)
			
			local slots = submarine.Info.RecommendedCrewSizeMax
			for character in Character.CharacterList do
				if (slots < 0) and (teamSubCount[value.Team] > 1) then break end
				if (not movedCharacterSet[character]) and (character.TeamID == value.Team) then
					local waypoint = findRandomWaypointByJob(submarine, character.JobIdentifier)
					if waypoint == nil then waypoint = findRandomWaypointByJob(submarine, '') end
					character.TeleportTo(waypoint.WorldPosition)
					
					movedCharacterSet[character] = true
					slots = slots - 1
				end
			end
		end
		teamSubCount[value.Team] = teamSubCount[value.Team] - 1
	end
	
	-- far away positions
	local xPosition = 0
	local yPosition = Level.Loaded.Size.Y + 10000
	-- lock team 1 sub
	xPosition = xPosition + Submarine.MainSub.Borders.Width * 2
	Submarine.MainSub.SetPosition(Vector2(xPosition, yPosition))
	sb.ResetSubmarineSteering(Submarine.MainSub)
	Submarine.MainSub.GodMode = false
	-- lock team 2 sub
	xPosition = xPosition + enemyMainSub.Borders.Width * 2
	enemyMainSub.SetPosition(Vector2(xPosition, yPosition))
	sb.ResetSubmarineSteering(enemyMainSub)
	enemyMainSub.GodMode = false
end

sb.MoveSubmarineToOther = function (sub1, sub2, vector)
    local vector = vector or Vector2(sub2.FlippedX and -0.5 or 0.5, -1) -- defaults to moving under the other submarine
    local radius = math.max(math.abs(vector.x), math.abs(vector.y))
    local dir = Vector2(vector.x / radius, vector.y / radius)

    local position = sub2.WorldPosition
    local offset = Vector2(sub1.SubBody.Borders.Width + sub2.SubBody.Borders.Width, sub1.SubBody.Borders.Height + sub2.SubBody.Borders.Height) / 2 * dir
    local padding = Vector2(math.sign(offset.x), math.sign(offset.y)) * 300
    sub1.SetPosition(position + offset + padding)
    sub1.EnableMaintainPosition()
end

Hook.Add("roundEnd", "SubmarineBuilder.RoundEnd", function ()
    for key, value in pairs(sb.Submarines) do
        if value.IsTemporary then
            sb.Submarines[key] = nil
        end
    end
end)

return sb