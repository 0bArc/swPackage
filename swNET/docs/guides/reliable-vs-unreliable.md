# Reliable vs unreliable

| | Reliable | Unreliable |
|---|---|---|
| Remote | `SwNetReliable` | `SwNetUnreliable` |
| Drop | Resend semantics of reliable remotes | May drop |
| Use | State, inventory, match setup | Aim, pose, scrubbers |

Set once on `definePacket`. Mixing rates: put high-rate fields on unreliable packets, not as spam on reliable.
