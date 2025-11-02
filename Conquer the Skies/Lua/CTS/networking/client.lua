if SERVER or Game.IsSingleplayer then return end

local message = Networking.Start("cts_pingOutsideHasOxygen")
Networking.Send(message)

Networking.Receive("cts_setOutsideHasOxygen", function (message, client)
	CTS.setOutsideHasOxygen(message.ReadBoolean())
end)