if SERVER or Game.IsSingleplayer then return end

local message = Networking.Start("cts_getSettings")
Networking.Send(message)

Networking.Receive("cts_setSettings", function (message, client)
	CTS.setOutsideHasOxygen(message.ReadBoolean())
	CTS.setMonstersFly(message.ReadBoolean())
end)