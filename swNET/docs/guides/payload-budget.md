# Payload budget

Rough sizes:

| Field | Bytes |
|---|---|
| packet id | 1 |
| color3 | 3 |
| vec3 | 12 |
| cframe | 24 |
| uint16 | 2 |
| string "hello" | 2 + 5 |

Design packets so the common case is tiny. Move rare bulky data (long strings, many instances) to infrequent reliable packets.

Inbound server messages larger than 1MB are ignored. Reference table overflow errors when a batch exceeds 255 refs.
