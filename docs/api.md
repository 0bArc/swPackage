# API reference

## Top level

```luau
SwNet.defineNamespace(name, function()
	return { packetName = SwNet.definePacket({ ... }) }
end)

SwNet.definePacket({
	value = <codec>,
	reliabilityType = "reliable" | "unreliable", -- optional, default reliable
})
```

Also exported: `define_namespace`, `define_packet` aliases.

## Packet instance (server)

| Method | Role |
|---|---|
| `sendTo(data, player)` | one player |
| `sendToAll(data)` | everyone |
| `sendToList(data, players)` | list (shared encode when possible) |
| `sendToAllExcept(data, player)` | everyone but one |
| `listen(callback)` | `callback(data, player?)` |
| `wait()` | yield for next |
| `getListeners()` | internal list |

## Packet instance (client)

| Method | Role |
|---|---|
| `send(data)` | to server |
| `listen(callback)` | `callback(data, player?)` |
| `wait()` | yield for next |

## Codecs

Factories / values on `SwNet`:

`array`, `bool`, `optional`, `uint8`, `uint16`, `uint32`, `int8`, `int16`, `int32`,
`float32`, `float64`, `cframe`, `color3`, `string`, `vec2`, `vec3`, `buff`,
`struct`, `map`, `inst`, `unknown`, `nothing`

### struct(fields)

Server records field order into namespace schema; client reads the replicated order so both sides agree without sorting keys each time.

### optional(inner)

Writes a bool presence then inner if present.

### array(inner)

u16 length + items.

### map(keyCodec, valueCodec)

Keyed pairs with a length prefix.

### color3

3 bytes (`R*255`, `G*255`, `B*255` as u8). Fixed `length = 3`.

### cframe

24 bytes: position xyz + axis*angle xyz (float32). Read/write agree on axis-angle packing.

## Remotes

Created at server start:

- `ReplicatedStorage.SwNetReliable`
- `ReplicatedStorage.SwNetUnreliable`
- `ReplicatedStorage.SwNetStorage` (schema folder)
