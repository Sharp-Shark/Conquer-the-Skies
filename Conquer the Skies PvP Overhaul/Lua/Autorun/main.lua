-- Conquer the Skies table
if CTS == nil then print('[!] Mod "Conquer the Skies PvP Overhaul" needs to be loaded after the "Conquer the Skies" mod.') return end

CTS.roundStartFunctions.main = function (luaReloaded)
	if Submarine.MainSub ~= nil then
		-- automations for sub editor
		if CLIENT and Game.IsSingleplayer and Game.IsSubEditor then
			local identifierResetSet = {
				aerialchargeshell = true,
				mortarshell = true,
				divingknife = true,
				boardingaxe = true,
				abyssdivingsuit = true,
				slipsuit = true,
				cargoscooter = true,
				underwaterscooter = true,
				extinguisher = true,
				machinepistol = true,
				spear = true,
				alienspear = true,
				spearunique = true,
			}
			for item in Item.ItemList do
				-- reset item
				if identifierResetSet[tostring(item.Prefab.Identifier)] and (not item.HasTag('noreset')) then
					item.Reset()
				end
			end
		end
	end
	
	-- Announce ships of each team
	if Game.IsSingleplayer or CLIENT then return end
	Timer.Wait(function ()
		for s in Submarine.Loaded do
			if (s.TeamID == 1) or (s.TeamID == 2) then
				for c in Client.ClientList do
					local msg = ChatMessage.Create('[Intel]', s.Info.Name, ChatMessageType.Server, nil, nil)
					msg.Color = Color.Orange
					if s.TeamID == 1 then msg.Color = Color.Cyan end
					Game.SendDirectChatMessage(msg, c)
				end
			end
		end
	end, 1000)
end

-- I hate Ballast Flora
Hook.Patch("Barotrauma.MapCreatures.Behavior.BallastFloraBehavior", "Update", function(instance, ptable)
	instance.Kill()
end, Hook.HookMethodType.After)