# Usage

```luau
local SwNet = require(path.to.swNET)

local packets = SwNet.defineNamespace("game", function()
	return {
		ping = SwNet.definePacket({
			value = SwNet.struct({
				t = SwNet.float64,
				tint = SwNet.color3,
			}),
			reliabilityType = "reliable",
		}),
		aim = SwNet.definePacket({
			value = SwNet.struct({
				look = SwNet.vec3,
			}),
			reliabilityType = "unreliable",
		}),
	}
end)

-- server
packets.ping.sendToAll({ t = os.clock(), tint = Color3.new(1, 0, 0) })
packets.ping.sendTo(player, data)
packets.ping.sendToList({ p1, p2 }, data)
packets.ping.sendToAllExcept(data, exceptPlayer)

-- client
packets.aim.send({ look = camera.CFrame.LookVector })

-- both
packets.ping.listen(function(data, player)
	print(data.t)
end)
```

Remotes under `ReplicatedStorage`: `SwNetReliable`, `SwNetUnreliable`, `SwNetStorage`.

With swTASK: see [guides/with-swtask.md](guides/with-swtask.md).
