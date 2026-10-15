# Batching and writer model

Each send loads a channel, writes packet id (u8) + payload via `writePacket`, and marks the channel dirty.

Heartbeat dumps dirty channels to remotes and clears cursors / references.

## writePacket

```text
load(channel) -> write u8(id) -> codec.write(data) -> export(channel)
```

## encode once for many players

`sendToList` / `sendToAllExcept` use `encodePacket` into a scratch buffer, then `appendEncoded` into each player channel when there are no refs. If refs exist, it falls back to per-player serialize (ref indices are batch-local).

## Capacity

Writer grows buffers by doubling when needed (`ensureCapacity`). `u8NoAlloc` exists for codecs that `alloc` a fixed span first (see `color3`).
