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