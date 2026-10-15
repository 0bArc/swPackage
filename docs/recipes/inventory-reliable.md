# Recipe: inventory (reliable)

```luau
local packets = SwNet.defineNamespace("inv", function()
	return {
		set = SwNet.definePacket({
			value = SwNet.struct({
				slot = SwNet.uint8,
				itemId = SwNet.uint16,
				count = SwNet.uint16,
			}),
			reliabilityType = "reliable",
		}),
	}
end)

-- server after mutation
packets.set.sendTo(player, { slot = 1, itemId = 50, count = 3 })
```
