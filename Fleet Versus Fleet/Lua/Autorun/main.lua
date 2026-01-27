if CLIENT then return end

-- Fleet Versus Fleet table
if FVF == nil then FVF = {} end

-- Set up the mod's path
FVF.path = table.pack(...)[1]

-- Enabled
FVF.enabled = true

-- Get access to the C#
FVF.FleetClass = LuaUserData.RegisterType('Fleet.FleetMod')
FVF.optionSubmarineInfo = FVF.FleetClass.Type.OptionSubmarineInfo

-- Requirements
FVF.submarineBuilder = dofile(FVF.path .. "/Lua/FVF/submarinebuilder.lua")

-- Pre-Start
if SERVER then
	Hook.Patch("Barotrauma.Networking.GameServer", "InitiateStartGame", function (instance, ptable)
		if not FVF.enabled then return end
		if Game.ServerSettings.GameModeIdentifier ~= "pvp" then return end
		if FVF.submarineBuilder == nil then return end

		local teamCount = {[1] = 0, [2] = 0}
		for client in Client.ClientList do
			if teamCount[client.TeamID] == nil then teamCount[client.TeamID] = 0 end
			if not client.SpectateOnly then
				teamCount[client.TeamID] = teamCount[client.TeamID] + 1
			end
		end
		
		if Game.ServerSettings.BotSpawnMode == 0 then
			-- Normal
			teamCount[1] = teamCount[1] + Game.ServerSettings.BotCount
			teamCount[2] = teamCount[2] + Game.ServerSettings.BotCount
		elseif Game.ServerSettings.BotSpawnMode == 1 then
			-- Fill
			teamCount[1] = math.max(teamCount[1], Game.ServerSettings.BotCount)
			teamCount[2] = math.max(teamCount[2], Game.ServerSettings.BotCount)
		end

		local submarineInfo = ptable["selectedSub"]
		local submarineCount = math.max(0, math.ceil(teamCount[1] / math.max(1, submarineInfo.RecommendedCrewSizeMax)))

		local enemySubmarineInfo = table.pack(ptable["selectedEnemySub"].TryUnwrap())[2] or submarineInfo
		local enemySubmarineCount = math.max(0, math.ceil(teamCount[2] / math.max(1, enemySubmarineInfo.RecommendedCrewSizeMax)))
		
		for i = 1, submarineCount do
			FVF.submarineBuilder.AddSubmarine(submarineInfo.FilePath, 'Coalition Submarine #' .. i, true, 1)
		end

		for i = 1, enemySubmarineCount do
			FVF.submarineBuilder.AddSubmarine(enemySubmarineInfo.FilePath, 'Separatist Submarine #' .. i, true, 2)
		end
		
		FVF.submarineBuilder.UpdateLobby(nil, nil, true)
		if submarineInfo.Name ~= "submarineinjector" then ptable["selectedSub"] = FVF.submarineBuilder.BuildSubmarines(1) end
		if enemySubmarineInfo.Name ~= "submarineinjector" then ptable["selectedEnemySub"] = FVF.optionSubmarineInfo(FVF.submarineBuilder.BuildSubmarines(2)) end
	end)
	
	Hook.Add("roundStart", "Traitormod.RoundStart", function()
		if not FVF.enabled then return end
		if Game.ServerSettings.GameModeIdentifier ~= "pvp" then return end
		FVF.submarineBuilder.RoundStart()
	end)
end