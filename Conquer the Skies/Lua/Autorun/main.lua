-- Conquer the Skies table
if CTS == nil then CTS = {} end

-- Set up the mod's path
CTS.path = table.pack(...)[1]

-- Load utilities/dependencies
if File.Exists(CTS.path .. '/CTS/secret.lua') then
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

-- Load other files
require 'CTS/fleet'
require 'CTS/networking/server'

-- Execute at round start
Hook.Add("roundStart", "CTS.prepareRound", function ()

	doRoundStartFunctions()
	
	return true
end)

-- Pre-Start
if SERVER then
	Hook.Patch("Barotrauma.Networking.GameServer", "InitiateStartGame", function (instance, ptable)
		if CTS.fleet == nil then return end

		CTS.brick = CTS.fleet.AddSubmarine(CTS.path .. '/Submarines/HMS Brick.sub', 'HMS Brick', true)

		ptable["selectedShuttle"] = CTS.fleet.BuildSubmarines()
	end)
end

-- Round start functions called at lua script execution just incase reloadlua is called mid-round
doRoundStartFunctions()