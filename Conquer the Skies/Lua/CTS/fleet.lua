-- https://github.com/evilfactory/traitormod/blob/master/Lua/submarinebuilder.lua

CTS.FlipSubmarine = function (submarine, flipCharacters)
    submarine.FlipX()
    if flipCharacters then
        for character in Character.CharacterList do
            if character.Submarine == submarine then
                local offsetX = character.WorldPosition.X - submarine.WorldPosition.X
                character.TeleportTo(Vector2(submarine.WorldPosition.X - offsetX, character.WorldPosition.Y))
            end
        end
    end
    if SERVER then
        local message = Networking.Start("syncsubflippedx")
        message.WriteUInt16(submarine.ID)
        message.WriteBoolean(submarine.FlippedX)
        Networking.Send(message)
    end
end

--[[ flips sub so it faces the way it is going
CTS.thinkFunctions.main = function ()
	for submarine in Submarine.Loaded do
        if submarine.FlippedX and submarine.Velocity.X >= 1 then
            CTS.FlipSubmarine(submarine, true)
        end
        if not submarine.FlippedX and submarine.Velocity.X <= -1 then
            CTS.FlipSubmarine(submarine, true)
        end
	end
end
]]--

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

    return
end

Game.OverrideRespawnSub(true) -- remove respawn submarine logic

local linkedSubmarineHeader = [[<LinkedSubmarine description="" checkval="2040186250" price="1000" initialsuppliesspawned="false" type="Player" tags="Shuttle" gameversion="0.17.4.0" dimensions="1270,451" cargocapacity="0" recommendedcrewsizemin="1" recommendedcrewsizemax="2" recommendedcrewexperience="Unknown" requiredcontentpackages="Vanilla" name="%s" filepath="Content/Submarines/Selkie.sub" pos="-64,-392.5" linkedto="4" originallinkedto="0" originalmyport="0">%s</LinkedSubmarine>]]

CTS.fleet = {}

CTS.fleet.Fleets = {}

CTS.fleet.FlipSubmarine = CTS.FlipSubmarine

CTS.fleet.IsActive = function ()
    return Game.GetRespawnSub() ~= nil
end

CTS.fleet.UpdateLobby = function(submarineInfo)
    local submarines = Game.NetLobbyScreen.subs

    for key, value in pairs(submarines) do
        if value.Name == "submarineinjector" then
            table.remove(submarines, key)
        end
    end

    table.insert(submarines, submarineInfo)
    SubmarineInfo.AddToSavedSubs(submarineInfo)

    Game.NetLobbyScreen.subs = submarines
    Game.NetLobbyScreen.SelectedShuttle = submarineInfo

    for _, client in pairs(Client.ClientList) do
        client.InitialLobbyUpdateSent = false
        Networking.ClientWriteLobby(client)
    end
end

CTS.fleet.Submarines = {}
CTS.fleet.SubmarineFleet = {}

CTS.fleet.AddSubmarine = function (path, name, isTemporary, fleet)
    isTemporary = isTemporary or false

    local submarineInfo = SubmarineInfo(path)

    name = name or submarineInfo.Name

    local xml = tostring(submarineInfo.SubmarineElement)

    local _, endPos = string.find(xml, ">")
    local startPos, _ = string.find(xml, "</Submarine>")

    local data = string.sub(xml, endPos + 1, startPos - 1)

    table.insert(CTS.fleet.Submarines, {Name = name, Data = data, IsTemporary = isTemporary, Fleet = fleet})

    return name
end

CTS.fleet.FindSubmarine = function (name)
    for _, submarine in pairs(Submarine.Loaded) do
        if submarine.Info.Name == name then
            return submarine
        end
    end
end

CTS.fleet.ResetSubmarineSteering = function (submarine)
    if submarine == nil then error("ResetSubmarineSteering: submarine was nil", 2) end
    for _, item in pairs(submarine.GetItems(true)) do
        local steering = item.GetComponentString("Steering")
        if steering then
            steering.AutoPilot = true
            steering.MaintainPos = true
            steering.PosToMaintain = submarine.WorldPosition
            steering.UnsentChanges = true
        end
    end
end

CTS.fleet.BuildSubmarines = function()
    local submarineInjector = File.Read(CTS.path .. "/Submarines/submarineinjector.xml")
    local result = ""

    for k, v in pairs(CTS.fleet.Submarines) do
        result = result .. string.format(linkedSubmarineHeader, v.Name, v.Data)
    end

    local submarineText = string.format(submarineInjector, result)

    File.Write(CTS.path .. "/Submarines/temp.xml", submarineText)
    local submarineInfoXML = SubmarineInfo(CTS.path .. "/Submarines/temp.xml")
    submarineInfoXML.SaveAs(CTS.path .. "/Submarines/temp.sub")

    local submarineInfo = SubmarineInfo(CTS.path .. "/Submarines/temp.sub")

    CTS.fleet.UpdateLobby(submarineInfo)
    return submarineInfo
end

CTS.fleet.RoundStart = function ()
    if Game.GetRespawnSub() == nil then return end

    for _, item in pairs(Game.GetRespawnSub().GetItems(false)) do
        local dockingPort = item.GetComponentString("DockingPort")
        if dockingPort then
            dockingPort.Undock()
        end
    end

    local xPosition = 0
    local yPosition = Level.Loaded.Size.Y + 10000

    for _, value in pairs(CTS.fleet.Submarines) do
        local submarine = CTS.fleet.FindSubmarine(value.Name)

        if submarine then
            xPosition = xPosition + submarine.Borders.Width * 2
            submarine.SetPosition(Vector2(xPosition, yPosition))
            submarine.GodMode = true
        end

        CTS.fleet.ResetSubmarineSteering(submarine)
    end

    CTS.fleet.Fleets = {
        [1] = {
            TeamID = 1,
            CrewPerSub = Submarine.MainSub.Info.RecommendedCrewSizeMax,
            Main = Submarine.MainSub,
            Anchor = Submarine.MainSub,
            Subs = {Submarine.MainSub},
            Crew = {},
            SubCrew = {[Submarine.MainSub] = {}}
        },
        [2] = {
            TeamID = 2,
            CrewPerSub = 1,
            Subs = {},
            Crew = {},
            SubCrew = {}
        },
    }
    CTS.fleet.SubmarineFleet[Submarine.MainSub] = CTS.fleet.Fleets[1]
    for submarine in Submarine.Loaded do
        if submarine.TeamID == CharacterTeamType.Team2 then
            CTS.fleet.Fleets[2].CrewPerSub = Submarine.MainSub.Info.RecommendedCrewSizeMax
            CTS.fleet.Fleets[2].Main = submarine
            CTS.fleet.Fleets[2].Anchor = submarine
            CTS.fleet.Fleets[2].Subs = {submarine}
            CTS.fleet.Fleets[2].SubCrew[submarine] = {}
            CTS.fleet.SubmarineFleet[submarine] = CTS.fleet.Fleets[2]
            break
        end
    end
    for character in Character.CharacterList do
        if CTS.fleet.Fleets[character.TeamID] ~= nil then
            table.insert(CTS.fleet.Fleets[character.TeamID].Crew, character)
        end
    end

    for tbl in CTS.fleet.Submarines do
        if tbl.Fleet ~= nil then
            local submarine = CTS.fleet.FindSubmarine(tbl.Name)
            if CTS.fleet.Fleets[tbl.Fleet] ~= nil then
                CTS.fleet.InitSubmarineToFleet(submarine, CTS.fleet.Fleets[tbl.Fleet])
            end
        end
    end
    CTS.fleet.Fleets[1].CrewPerSub = math.ceil(#CTS.fleet.Fleets[1].Crew / math.max(1, #CTS.fleet.Fleets[1].Subs))
    CTS.fleet.Fleets[2].CrewPerSub = math.ceil(#CTS.fleet.Fleets[2].Crew / math.max(1, #CTS.fleet.Fleets[2].Subs))

    -- spread crew among fleet
    for fleet in CTS.fleet.Fleets do
        local submarineIndex = 1
        for character in fleet.Crew do
            submarine = fleet.Subs[submarineIndex]

            local waypoint = CTS.findRandomWaypointByJob(submarine, character.JobIdentifier)
            if waypoint == nil then waypoint = CTS.findRandomWaypointByJob(submarine, '') end
            character.TeleportTo(waypoint.WorldPosition)

            table.insert(fleet.SubCrew[submarine], character)
            if #fleet.SubCrew[submarine] >= fleet.CrewPerSub then
                submarineIndex = math.min(#fleet.Subs, submarineIndex + 1)
            end
        end
    end

    CTS.fleet.PruneSubmarines()
end

CTS.fleet.MoveSubmarineToOther = function (sub1, sub2, vector)
    local vector = vector or Vector2(sub2.FlippedX and -0.5 or 0.5, -1) -- defaults to moving under the other submarine
    local radius = math.max(math.abs(vector.x), math.abs(vector.y))
    local dir = Vector2(vector.x / radius, vector.y / radius)

    local position = sub2.WorldPosition
    local offset = Vector2(sub1.SubBody.Borders.Width + sub2.SubBody.Borders.Width, sub1.SubBody.Borders.Height + sub2.SubBody.Borders.Height) / 2 * dir
    local padding = Vector2(math.sign(offset.x), math.sign(offset.y)) * 250
    sub1.SetPosition(position + offset + padding)
    sub1.EnableMaintainPosition()
end

CTS.fleet.InitSubmarineToFleet = function (submarine, fleet, vector)
    local parent = fleet.Anchor
    CTS.fleet.MoveSubmarineToOther(submarine, parent, vector)
    submarine.TeamID = parent.TeamID
    submarine.GodMode = false
    if submarine.FlippedX ~= parent.FlippedX then CTS.fleet.FlipSubmarine(submarine) end

    table.insert(fleet.Subs, submarine)
    fleet.SubCrew[submarine] = {}
    fleet.Anchor = submarine
    CTS.fleet.SubmarineFleet[submarine] = fleet
end

CTS.fleet.pruned = false
CTS.fleet.PruneSubmarines = function ()
    CTS.fleet.pruned = true
    Entity.Spawner.AddEntityToRemoveQueue(CTS.fleet.FindSubmarine('sacrifice_for_the_lua_gods'))
    for tbl in CTS.fleet.Submarines do
        local bool = false
        for submarine in Submarine.Loaded do
            if submarine.Info.Name == tbl.Name then
                if bool then
                    Entity.Spawner.AddEntityToRemoveQueue(submarine)
                else
                    bool = true
                end
            end
        end
    end
end

Hook.Add("roundEnd", "SubmarineBuilder.RoundEnd", function ()
    CTS.fleet.pruned = false
    CTS.fleet.Fleets = {}
    for key, value in pairs(CTS.fleet.Submarines) do
        if value.IsTemporary then
            CTS.fleet.Submarines[key] = nil
        end
    end
end)

local syncsubflippedx_next = Timer.Time + 1
CTS.thinkFunctions.syncsubflippedx = function ()
    local time = Timer.Time
    if time < syncsubflippedx_next then return end
    syncsubflippedx_next = time + 1

    for submarine in Submarine.Loaded do
        local message = Networking.Start("syncsubflippedx")
        message.WriteUInt16(submarine.ID)
        message.WriteBoolean(submarine.FlippedX)
        Networking.Send(message)
    end
end