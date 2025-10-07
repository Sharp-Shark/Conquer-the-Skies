-- Conquer the Skies table
if CTS == nil then CTS = {} end

-- Set up the mod's path
CTS.path = table.pack(...)[1]

-- Load utilities/dependencies
if File.Exists(CTS.path .. '/Lua/CTS/secret.lua') then
	require 'CTS/secret'
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


-- Pre-Start
if SERVER then
	--LuaUserData.RegisterType('Barotrauma.Option`1[Barotrauma.SubmarineInfo]')
	LuaUserData.RegisterType('Barotrauma.Option`1[[Barotrauma.SubmarineInfo]],BarotraumaCore')
	Hook.Patch("Barotrauma.Networking.GameServer", "InitiateStartGame", function (instance, ptable)
		if CTS.fleet == nil then return end

		local teamCount = {[1] = 0, [2] = 0}
		for client in Client.ClientList do
			if teamCount[client.TeamID] == nil then teamCount[client.TeamID] = 0 end
			teamCount[client.TeamID] = teamCount[client.TeamID] + 1
		end

		teamCount[1] = 15 -- remove this line later when testing is over
		teamCount[2] = 15 -- remove this line later when testing is over

		local submarineInfo = ptable["selectedSub"]
		local submarineCount = math.floor((teamCount[1] - 1) / math.max(1, submarineInfo.RecommendedCrewSizeMax))

		local enemySubmarineInfo = table.pack(ptable["selectedEnemySub"].TryUnwrap())[2]
		local enemySubmarineCount = math.floor((teamCount[2] - 1) / math.max(1, enemySubmarineInfo.RecommendedCrewSizeMax))
		if Game.ServerSettings.GameModeIdentifier ~= 'pvp' then
			enemySubmarineCount = 0
		end

		-- for some reason the first submarine the auto-injector places gets bugged, so I spawn this one first and later remove it
		CTS.fleet.padding = CTS.fleet.AddSubmarine(submarineInfo.FilePath, 'sacrifice_for_the_lua_gods', true)

		for i = 1, submarineCount do
			CTS.fleet.AddSubmarine(submarineInfo.FilePath, 'submarine' .. i, true, 1)
		end

		for i = 1, enemySubmarineCount do
			CTS.fleet.AddSubmarine(enemySubmarineInfo.FilePath, 'enemySubmarine' .. i, true, 2)
		end

		ptable["selectedShuttle"] = CTS.fleet.BuildSubmarines()
	end)
end

-- Round start functions called at lua script execution just incase reloadlua is called mid-round
doRoundStartFunctions()