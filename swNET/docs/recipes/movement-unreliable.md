# Recipe: movement (unreliable)

```luau
local packets = SwNet.defineNamespace("move", function()
	return {
		pose = SwNet.definePacket({
			value = SwNet.struct({
				pos = SwNet.vec3,
				yaw = SwNet.float32,
			}),
			reliabilityType = "unreliable",
		}),
	}
end)

-- client Heartbeat
packets.pose.send({
	pos = character:GetPivot().Position,
	yaw = getYaw(),
})
```
