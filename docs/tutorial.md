# Tutorial

## 1. Require and define a namespace

Namespaces group packets and sync struct field order from server to client.

```luau
local SwNet = require(path.to.swNET)

local packets = SwNet.defineNamespace("combat", function()
	return {
		hit = SwNet.definePacket({
			value = SwNet.struct({
				targetId = SwNet.uint32,
				damage = SwNet.uint16,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
```

Define the same namespace on server and client. Server assigns packet ids (u8, max 255 total across namespaces) and replicates schema through `SwNetStorage`.

## 2. Understand the value field

`definePacket` takes `value` = a codec (usually a `struct`). That codec's `write`/`read` define the wire bytes.

```luau
SwNet.definePacket({
	value = SwNet.struct({
		id = SwNet.uint16,
		name = SwNet.string,
		tint = SwNet.color3, -- 3 bytes RGB
		pos = SwNet.vec3,    -- 12 bytes
		cf = SwNet.cframe,   -- 24 bytes axis-angle
	}),
})
```

## 3. Reliability

`reliabilityType` is `"reliable"` (default) or `"unreliable"` (case-insensitive). Invalid values error at define time.

- Reliable: inventory, match state, one-shot events you cannot drop
- Unreliable: aim, pose, high-rate samples where newest wins

## 4. Send API

Server:

- `sendTo(data, player)`
- `sendToAll(data)`
- `sendToList(data, players)` (serialize once when there are no instance/unknown refs)
- `sendToAllExcept(data, player)`

Client:

- `send(data)`

Wrong side usage errors (client cannot `sendToAll`, server cannot `send`).

## 5. Listen and wait

```luau
packets.hit.listen(function(data, player)
	-- player is set for server-received client packets
end)

-- yield until next packet
local data, player = packets.hit.wait()
```

## 6. Batching

Sends append into per-channel buffers. Each Heartbeat, dirty channels flush to remotes. You do not fire one remote per packet call.

Server also:

- Caps inbound buffer size (1MB)
- Checks references is a table when present
- Clears channels on PlayerRemoving
- Uses a dirty set so idle players are not scanned every frame

## 7. Codecs worth knowing

| Codec | Wire (approx) | Use |
|---|---|---|
| uint8/16/32, int8/16/32 | 1-4 | ids, counts, enums |
| float32/64 | 4/8 | continuous values |
| bool | 1 | flags |
| string | 2 + bytes | text (u16 length) |
| vec2/vec3 | 8/12 | positions, directions |
| cframe | 24 | fixed axis-angle |
| color3 | 3 | RGB bytes |
| optional(T) | 1 + T? | presence flag |
| array(T) | 2 + n*T | lists |
| map(K,V) | length + pairs | dictionaries |
| inst / unknown | 1 + ref slot | avoid on hot paths |
| nothing | 0 | empty payload |
| buff | length + bytes | raw buffers |

## 8. Pair with swTASK

```luau
local SwTask = require(path.to.swTASK)
SwTask.swnet:attach(SwNet)

packets.hit.listen(SwTask.swnet:on(function(data, player)
	applyHit(player, data)
end))
```

## 9. Practice exercise

1. Namespace `demo` with reliable `chat` (string) and unreliable `cursor` (vec2).
2. Client sends cursor every Heartbeat.
3. Server listens and prints rate-limited positions.
4. Wrap listeners in `SwTask.swnet:on` if swTASK is available.
