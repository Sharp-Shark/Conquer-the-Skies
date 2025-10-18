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