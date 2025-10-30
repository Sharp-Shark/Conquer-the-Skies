Hook.Add("CTS.aerialcharge.onspawn", "CTS.aerialcharge.onspawn", function(effect, deltaTime, item, targets, worldPosition)
    item.body.FarseerBody.IgnoreGravity = true
end)
Hook.Add("CTS.aerialcharge.onnotcontained", "CTS.aerialcharge.onnotcontained", function(effect, deltaTime, item, targets, worldPosition)
    item.body.ApplyForce(Vector2(0, 10))
    
    local rotation = (item.body.Rotation + math.pi) % (math.pi * 2) - math.pi
    if item.FlippedX ~= item.FlippedY then
        if rotation >= math.pi / 2 then
            item.body.ApplyTorque(-2 * (math.pi / -2 - rotation))
        else
            item.body.ApplyTorque(2 * (math.pi / -2 - rotation))
        end
    else
        if rotation <= math.pi / -2 then
            item.body.ApplyTorque(-2 * (math.pi / 2 - rotation))
        else
            item.body.ApplyTorque(2 * (math.pi / 2 - rotation))
        end
    end
    item.body.ApplyTorque(item.body.AngularVelocity * -0.1)
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