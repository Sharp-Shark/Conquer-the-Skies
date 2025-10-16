-- Conquer the Skies table
if CTS == nil then CTS = {} end

-- Set up the mod's path
CTS.path = table.pack(...)[1]

-- Get access to the C#
CTS.NoWaterClass = LuaUserData.RegisterType('NoWater.NoWaterMod')

-- Load utilities/dependencies
if File.Exists(CTS.path .. '/Lua/CTS/secret.lua') then
	require 'CTS/secret'
end

-- Functions executed at round start
CTS.roundStartFunctions = {}
local doRoundStartFunctions = function (luaReloaded)
	for name, func in pairs(CTS.roundStartFunctions) do
		func(luaReloaded)
	end
end
CTS.roundStartFunctions.main = function (luaReloaded)
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

	-- do not spread spread crew if this method was caused due to lua being reloaded
	if luaReloaded then return end

	local teamData = {
		[1] = {
			crew = {},
			submarines = {Submarine.MainSubs[1]},
			crewPerSub = 0,
			anchor = Submarine.MainSubs[1],
		},
		[2] = {
			crew = {},
			submarines = {Submarine.MainSubs[2]},
			crewPerSub = 0,
			anchor = Submarine.MainSubs[2],
		},
	}

    for character in Character.CharacterList do
		if teamData[character.TeamID] ~= nil then
			table.insert(teamData[character.TeamID].crew, character)
		end
	end

	local submarines = CTS.NoWaterClass.Type.submarines
	for submarine in submarines do
		if teamData[submarine.TeamID] ~= nil then
			table.insert(teamData[submarine.TeamID].submarines, submarine)
		end
	end

	teamData[1].crewPerSub = math.ceil(#teamData[1].crew / math.max(1, #teamData[1].submarines))
	teamData[2].crewPerSub = math.ceil(#teamData[2].crew / math.max(1, #teamData[2].submarines))

	for team, data in pairs(teamData) do
        local submarineIndex = 1
		local submarineCrewCount = 0
		for character in data.crew do
			local submarine = data.submarines[submarineIndex]

			local waypoint = CTS.findRandomWaypointByJob(submarine, character.JobIdentifier)
			if waypoint == nil then waypoint = CTS.findRandomWaypointByJob(submarine, '') end
			character.TeleportTo(waypoint.WorldPosition)

			submarineCrewCount = submarineCrewCount + 1
			if submarineCrewCount >= data.crewPerSub then
				submarineIndex = math.min(#data.submarines, submarineIndex + 1)
				submarineCrewCount = 0
			end
		end
    end
end

-- Think functions
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

-- Sets ambient light and background for open skies biome
CTS.thinkFunctions.openskies = function ()
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

-- Manages submarine flippedX
CTS.autoSubFlip = false
local syncsubflippedx_next = Timer.Time + 1
CTS.thinkFunctions.syncsubflippedx = function ()
    local time = Timer.Time
	local syncsubflippedx = SERVER and (time >= syncsubflippedx_next)
    for submarine in Submarine.Loaded do
		if CTS.autoSubFlip then
			if submarine.FlippedX and submarine.Velocity.X >= 1 then
				CTS.flipSubmarine(submarine, true)
			end
			if not submarine.FlippedX and submarine.Velocity.X <= -1 then
				CTS.flipSubmarine(submarine, true)
			end
		end
		if syncsubflippedx then
        	local message = Networking.Start("syncsubflippedx")
        	message.WriteUInt16(submarine.ID)
        	message.WriteBoolean(submarine.FlippedX)
        	Networking.Send(message)
		end
    end
	if syncsubflippedx then syncsubflippedx_next = time + 1 end
end
if CLIENT then
    Networking.Receive("syncsubflippedx", function (message, client)
        local id = message.ReadUInt16()
        local flippedX = message.ReadBoolean()
        for submarine in Submarine.Loaded do
            if (submarine.ID == id) and (submarine.FlippedX ~= flippedX) then
                submarine.FlipX()
            end
        end
    end)
end

-- Load other files
require 'CTS/utilities'
require 'CTS/networking/server'
require 'CTS/luahooks'

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

-- Round start functions called at lua script execution just incase reloadlua is called mid-round
doRoundStartFunctions(true)