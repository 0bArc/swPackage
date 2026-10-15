# swNET

<p align="center">
  <img src="assets/swnet-logo.png" alt="swNET" width="220" />
</p>

Buffer-based Roblox networking. Define typed packets, batch them each frame, send over reliable/unreliable remotes.

**Docs:** [docs/index.md](docs/index.md) · [Branding](docs/branding.md)

## Layout

```
src/
  api/         packet + namespace registry
  codec/       data type encoders/decoders
  transport/   client + server batching
  writer/      channel buffer writer
  wire/        inbound decode + refs
  sync/        namespace schema sync
assets/        transparent logo (64-1024)
docs/          documentation
```

## Remotes

Created under `ReplicatedStorage`:

- `SwNetReliable`
- `SwNetUnreliable`
- `SwNetStorage` (namespace schema)

## Quick use

```luau
local SwNet = require(path.to.swNET)

local packets = SwNet.defineNamespace("game", function()
	return {
		ping = SwNet.definePacket({
			value = SwNet.struct({
				t = SwNet.float64,
				tint = SwNet.color3, -- 3 bytes RGB
			}),
		}),
	}
end)

-- server
packets.ping.sendToAll({ t = os.clock() })

-- client
packets.ping.listen(function(data)
	print(data.t)
end)
```

## Tests

```
python sim_test/test_swnet_fixes.py
```

## License

MIT. See `LICENSE` and `NOTICE`.

## Docs

- [Usage](docs/usage.md)
- [Tutorial](docs/tutorial.md)
- [API](docs/api.md)
- [Index](docs/index.md)
