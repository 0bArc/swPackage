# Namespaces and packets

A namespace game splits namespaces by domain: `combat`, `inventory`, `meta`.

```luau
local combat = SwNet.defineNamespace("combat", function()
	return {
		hit = SwNet.definePacket({ value = SwNet.struct({ ... }) }),
		reload = SwNet.definePacket({ value = SwNet.nothing }),
	}
end)
```

Packet ids are global u8 values incrementing on the server as packets are created. Cap is 255. If you hit the cap, split less aggressively or change protocol.

Clients must define the same keys; ids come from replicated namespace data, not from local counting.
