# Recipe: ping

```luau
local packets = SwNet.defineNamespace("meta", function()
	return {
		ping = SwNet.definePacket({
			value = SwNet.struct({ t = SwNet.float64 }),
		}),
	}
end)

-- client
packets.ping.send({ t = os.clock() })

-- server
packets.ping.listen(function(data, player)
	print(player, os.clock() - data.t)
end)
```
