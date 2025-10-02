-- https://github.com/evilfactory/traitormod/blob/master/Lua/submarinebuilder.lua

if CLIENT then return end

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

CTS.fleet.AddSubmarine = function (path, name, isTemporary)
    isTemporary = isTemporary or false

    local submarineInfo = SubmarineInfo(path)

    name = name or submarineInfo.Name

    local xml = tostring(submarineInfo.SubmarineElement)

    local _, endPos = string.find(xml, ">")
    local startPos, _ = string.find(xml, "</Submarine>")

    local data = string.sub(xml, endPos + 1, startPos - 1)

    table.insert(CTS.fleet.Submarines, {Name = name, Data = data, IsTemporary = isTemporary})

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
end

Hook.Add("roundEnd", "SubmarineBuilder.RoundEnd", function ()
    for key, value in pairs(CTS.fleet.Submarines) do
        if value.IsTemporary then
            CTS.fleet.Submarines[key] = nil
        end
    end
end)