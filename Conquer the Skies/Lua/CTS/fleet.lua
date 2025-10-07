-- https://github.com/evilfactory/traitormod/blob/master/Lua/submarinebuilder.lua

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

CTS.fleet = {}

local linkedSubmarineHeader = [[<LinkedSubmarine description="" checkval="2040186250" price="1000" initialsuppliesspawned="false" type="Player" tags="Shuttle" gameversion="0.17.4.0" dimensions="1270,451" cargocapacity="0" recommendedcrewsizemin="1" recommendedcrewsizemax="2" recommendedcrewexperience="Unknown" requiredcontentpackages="Vanilla" name="%s" filepath="Content/Submarines/Selkie.sub" pos="-64,-392.5" linkedto="4" originallinkedto="0" originalmyport="0">%s</LinkedSubmarine>]]

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

    local fleets = {
        [1] = Submarine.MainSub,
    }
    for submarine in Submarine.Loaded do
        if submarine.TeamID == CharacterTeamType.Team2 then
            fleets[2] = submarine
        end
    end
    --[[
    local crews = {
        [1] = {},
        [2] = {},
    }
    ]]--
    for tbl in CTS.fleet.Submarines do
        if tbl.Fleet ~= nil then
            local submarine = CTS.fleet.FindSubmarine(tbl.Name)
            if fleets[tbl.Fleet] ~= nil then
                CTS.fleet.InitSubmarineToFleet(submarine, fleets[tbl.Fleet])
                --[[
                for character in Character.CharacterList do
                end
                ]]-- CODE THAT MOVES PLAYERS FROM OVERPOPULATED SHIPS TO UNDERPOPULATED ONES WOULD GO HERE
                fleets[tbl.Fleet] = submarine
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

CTS.fleet.InitSubmarineToFleet = function (submarine, parent, vector)
    CTS.fleet.MoveSubmarineToOther(submarine, parent, vector)
    submarine.TeamID = parent.TeamID
    submarine.GodMode = false
    if submarine.FlippedX ~= parent.FlippedX then CTS.fleet.FlipSubmarine(submarine) end
end

CTS.fleet.FlipSubmarine = function (submarine, flipCharacters)
    submarine.FlipX()
    if flipCharacters then
        for character in Character.CharacterList do
            if character.Submarine == submarine then
                local offsetX = character.WorldPosition.X - submarine.WorldPosition.X
                character.TeleportTo(Vector2(submarine.WorldPosition.X - offsetX, character.WorldPosition.Y))
            end
        end
    end
    local message = Networking.Start("syncsubflippedx")
    message.WriteUInt16(submarine.ID)
    message.WriteBoolean(submarine.FlippedX)
    Networking.Send(message)
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