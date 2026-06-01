if CLIENT then return end

-- this file used to contain functionality to forward joins/leaves of public servers to a public channel (#server-status) in the discord server
-- however because someone complained and also because Conquer the Skies, although originally designed for Sub vs Sub, has been used for much more than that
-- I decided to move the functionality to the "Conquer the Skies PvP Overhaul" mod (you'll find the code in the "discord.lua" file)
-- the code for "Conquer the Skies PvP Overhaul" can be found in the same github repository as the one that contains this mod

CTS.syncSettings = function(connection)
	local message = Networking.Start("cts_setSettings")
	message.WriteBoolean(CTS.getOutsideHasOxygen())
	message.WriteBoolean(CTS.getMonstersFly())
	Networking.Send(message, connection)
end

Networking.Receive("cts_getSettings", function (message, client)
	CTS.syncSettings(client.Connection)
end)