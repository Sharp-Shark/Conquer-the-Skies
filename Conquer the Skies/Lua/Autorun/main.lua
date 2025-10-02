-- Conquer the Skies table
if CTS == nil then CTS = {} end

-- Load utilities/dependencies
require 'CTS/secret'

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
end

-- Load other files
require 'CTS/networking/server'

-- Execute at round start
Hook.Add("roundStart", "CTS.prepareRound", function ()

	doRoundStartFunctions()
	
	return true
end)

-- Round start functions called at lua script execution just incase reloadlua is called mid-round
doRoundStartFunctions()