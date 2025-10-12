-- Conquer the Skies table
if CTS == nil then CTS = {} end

-- Set up the mod's path
CTS.path = table.pack(...)[1]

-- Load utilities/dependencies
if File.Exists(CTS.path .. '/Lua/CTS/secret.lua') then
	require 'CTS/secret'
end

-- Make accessible to lua
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.Level"], "get_RandomHash")

-- Utility
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

-- Functions executed at round start
CTS.roundStartFunctions = {}
local doRoundStartFunctions = function ()
	for name, func in pairs(CTS.roundStartFunctions) do
		func()
	end
end
CTS.roundStartFunctions.main = function ()
	if Submarine.MainSub ~= nil then
		-- automations for sub editor
		if CLIENT and Game.IsSingleplayer and Game.IsSubEditor then
			local identifierResetSet = {
				slipsuit = true,
				cargoscooter = true,
				underwaterscooter = true,
				extinguisher = true,
				machinepistol = true,
			}
			for item in Item.ItemList do
				-- reset item
				if identifierResetSet[tostring(item.Prefab.Identifier)] and (not item.HasTag('noreset')) then
					item.Reset()
				end
			end
		end
	end

	if CTS.fleet == nil then return end
	CTS.fleet.RoundStart()
end

CTS.thinkFunctions = {}
CTS.newThinkFunctions = {}
local doThinkFunctions = function ()
	for name, func in pairs(CTS.newThinkFunctions) do
		CTS.thinkFunctions[name] = func
		CTS.newThinkFunctions[name] = nil
	end
	for name, func in pairs(CTS.thinkFunctions) do
		func()
	end
end

-- Load other files
require 'CTS/utilities'
require 'CTS/fleet'
require 'CTS/networking/server'

-- Execute at round start
Hook.Add("roundStart", "CTS.prepareRound", function ()

	doRoundStartFunctions()
	
	return true
end)

-- Executes constantly
CTS.thinkCounter = 0
Hook.Add("think", "DD.think", function ()
	CTS.thinkCounter = CTS.thinkCounter + 1
	
	doThinkFunctions()
	
	return true
end)
CTS.thinkFunctions.main = function ()
    if Level.Loaded == nil or Level.Loaded.LevelData.Biome.Identifier ~= 'openskies' then return end

	local parameters = Level.Loaded.LevelData.GenerationParams
	-- Color(50, 115, 170, 255)
	parameters.AmbientLightColor = Color(200, 200, 185, 255)
	parameters.BackgroundTextureColor = Color(50, 115, 170, 255)
	parameters.BackgroundColor = Color(50, 115, 170, 255)
	-- parameters.set_BackgroundSprite(Sprite("Content/amongus.jpg"))
	-- parameters.set_BackgroundTopSprite(Sprite("Content/amongus.jpg"))    Cat jumpscare!!!

	for submarine in Submarine.Loaded do
		for hull in submarine.GetHulls(true) do
			if hull.HiddenInGame then
				hull.AmbientLight = parameters.AmbientLightColor
			end
		end
	end
end

-- Pre-Start
if SERVER then
	LuaUserData.RegisterType('Barotrauma.Option`1[[Barotrauma.SubmarineInfo]],BarotraumaCore')
	Hook.Patch("Barotrauma.Networking.GameServer", "InitiateStartGame", function (instance, ptable)
		if CTS.fleet == nil then return end

		local teamCount = {[1] = 0, [2] = 0}
		for client in Client.ClientList do
			if teamCount[client.TeamID] == nil then teamCount[client.TeamID] = 0 end
			teamCount[client.TeamID] = teamCount[client.TeamID] + 1
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
		local submarineCount = math.max(0, math.ceil(teamCount[1] / math.max(1, submarineInfo.RecommendedCrewSizeMax)) - 1)

		local enemySubmarineInfo = table.pack(ptable["selectedEnemySub"].TryUnwrap())[2]
		local enemySubmarineCount = math.max(0, math.ceil(teamCount[2] / math.max(1, enemySubmarineInfo.RecommendedCrewSizeMax)) - 1)
		if Game.ServerSettings.GameModeIdentifier ~= 'pvp' then
			enemySubmarineCount = 0
		end

		-- for some reason the first submarine the auto-injector places gets bugged, so I spawn this one first and later remove it
		CTS.fleet.padding = CTS.fleet.AddSubmarine(submarineInfo.FilePath, 'sacrifice_for_the_lua_gods', true)

		for i = 1, submarineCount do
			CTS.fleet.AddSubmarine(submarineInfo.FilePath, 'Coalition Submarine #' .. (i + 1), true, 1)
		end

		for i = 1, enemySubmarineCount do
			CTS.fleet.AddSubmarine(enemySubmarineInfo.FilePath, 'Separatist Submarine #' .. (i + 1), true, 2)
		end

		ptable["selectedShuttle"] = CTS.fleet.BuildSubmarines()
	end)
end

-- Used to pose NPCs for screenshots
CTS.freeze = function (character, bool)
	local value = 0
	if bool then value = 2 end
	
	character.AnimController.Collider.BodyType = value
	for limb in character.AnimController.Limbs do
		limb.body.BodyType = value
	end
	
	print(character, ' state: ', value)
end

-- Round start functions called at lua script execution just incase reloadlua is called mid-round
doRoundStartFunctions()