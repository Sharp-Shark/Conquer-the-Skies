Hook.Add("CTS.aerialcharge.onspawn", "CTS.aerialcharge.onspawn", function(effect, deltaTime, item, targets, worldPosition)
    item.body.FarseerBody.IgnoreGravity = true
end)
Hook.Add("CTS.aerialcharge.onnotcontained", "CTS.aerialcharge.onnotcontained", function(effect, deltaTime, item, targets, worldPosition)
    item.body.ApplyForce(Vector2(0, 5))

    if item.FlippedX then
        item.body.ApplyTorque(1 * (math.pi / -2 - item.body.Rotation))
    else
        item.body.ApplyTorque(1 * (math.pi / 2 - item.body.Rotation))
    end
    item.body.ApplyTorque(item.body.AngularVelocity * -0.1)
end)