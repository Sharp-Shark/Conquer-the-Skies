Hook.Add("CTS.aerialcharge.onspawn", "CTS.aerialcharge.onspawn", function(effect, deltaTime, item, targets, worldPosition)
    item.body.FarseerBody.IgnoreGravity = true
end)
Hook.Add("CTS.aerialcharge.onnotcontained", "CTS.aerialcharge.onnotcontained", function(effect, deltaTime, item, targets, worldPosition)
    local dt = 60 * deltaTime
    item.body.ApplyLinearImpulse(Vector2(0, 0.25) * dt)
    
    local rotation = (item.body.Rotation + math.pi) % (math.pi * 2) - math.pi
    if item.FlippedX ~= item.FlippedY then
        if rotation >= math.pi / 2 then
            item.body.ApplyTorque(-2 * (math.pi / -2 - rotation) * dt)
        else
            item.body.ApplyTorque(2 * (math.pi / -2 - rotation) * dt)
        end
    else
        if rotation <= math.pi / -2 then
            item.body.ApplyTorque(-2 * (math.pi / 2 - rotation) * dt)
        else
            item.body.ApplyTorque(2 * (math.pi / 2 - rotation) * dt)
        end
    end
    item.body.ApplyTorque(item.body.AngularVelocity * -0.1 * dt)
end)

Hook.Add("CTS.torpedocharge.onnotcontained", "CTS.torpedocharge.onnotcontained", function(effect, deltaTime, item, targets, worldPosition)
    local dt = 60 * deltaTime

    local component = item.GetComponentString('Projectile')
    if (component == nil) or (not item.GetComponentString('Projectile').IsActive) then return end

    local norm = item.body.LinearVelocity.Length()
    if norm < 1 then return end

    item.body.ApplyLinearImpulse(0.6 * item.body.LinearVelocity / norm * dt)
    item.body.ApplyLinearImpulse(item.body.LinearVelocity * -0.1 * dt)
end)

Hook.Patch("Barotrauma.Items.Components.Wire", "RemoveConnection", {'Barotrauma.Item'}, function(instance, ptable)
    local item = ptable['item']
    if item == nil then return end
    if not item.HasTag('turret') then return end

    local component = item.GetComponentString('ConnectionPanel')
    if component == nil then return end

    local character = component.User
    if character == nil then return end
    if CLIENT and Game.IsSingleplayer and Game.IsSubEditor then return end

    local oldConnection
    for connection in instance.Connections do
        if connection.Item == item then
            oldConnection = connection
            break
        end
    end
    if oldConnection == nil then return end

    Timer.NextFrame(function ()
        local newConnection
        for connection in instance.Connections do
            if connection.Item == item then
                newConnection = connection
                break
            end
        end
        if connection == oldConnection or oldConnection == nil then return end

        CTS.giveAfflictionCharacter(character, 'stun', 4)
        CTS.giveAfflictionCharacter(character, 'electricshock', 60)
        CTS.giveAfflictionCharacter(character, 'burn', 5)
        Entity.Spawner.AddItemToSpawnQueue(ItemPrefab.GetItemPrefab('zapfx'), item.WorldPosition, nil, nil, function (spawnedItem) end)
    end)
end)

--[[ funny float physics
local float = {}
CTS.test = function (character, bool)
    character.AnimController.Collider.FarseerBody.IgnoreGravity = bool
    for limb in character.AnimController.Limbs do
        limb.body.FarseerBody.IgnoreGravity = bool
    end
    if bool then
        float[character] = true
    else
        float[character] = nil
    end
end

CTS.thinkFunctions.float = function ()
    for character, bool in pairs(float) do
        character.AnimController.Collider.ApplyForce(Vector2(0, 10))
        for limb in character.AnimController.Limbs do
            limb.body.ApplyForce(Vector2(0, 10))
        end
    end
end
]]--