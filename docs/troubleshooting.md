# Troubleshooting

## Client never receives packets

- Namespace defined on both sides?
- Server started so remotes exist before client `WaitForChild`?
- Listening on the same packet key?

## "packet ID limit is 255"

Too many packets across namespaces. Reduce packet count or redesign.

## invalid reliabilityType

Only `reliable` / `unreliable` (any case). Typos error at define time.

## Wrong CFrame rotation

Use current swNET cframe codec (axis-angle packed as axis*angle). Do not mix with older buggy unit-axis writes.

## sendTo on client errors

Server-only APIs. Client uses `send`.

## Heavy lag on sendToList with Instances

Refs force per-player serialize. Avoid `inst`/`unknown` in fanout packets.

## Listener blocks inbound batch

Move heavy work to `SwTask.swnet:on` or your own job queue.
