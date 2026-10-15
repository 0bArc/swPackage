# swTASK docs

<p align="center">
  <img src="../assets/swtask-logo.png" alt="swTASK" width="220" />
</p>

Structured concurrency for Luau. One colon-first API instead of `task.spawn`, coroutine graphs, and ad hoc cancel flags. Other modules plug in through adapters.

## Read in order

1. [usage.md](usage.md) - cheat sheet
2. [tutorial.md](tutorial.md) - learn by building
3. [principles.md](principles.md) - why the API looks like this
4. [api.md](api.md) - every public method

## Guides

- [jobs-and-await.md](guides/jobs-and-await.md)
- [flows-and-batching.md](guides/flows-and-batching.md)
- [scopes-and-cancel.md](guides/scopes-and-cancel.md)
- [safe-vs-cpu.md](guides/safe-vs-cpu.md)
- [adapting-modules.md](guides/adapting-modules.md)
- [with-swnet.md](guides/with-swnet.md)

## Recipes

- [replace-task-library.md](recipes/replace-task-library.md)
- [player-session.md](recipes/player-session.md)
- [datastore-profiles.md](recipes/datastore-profiles.md)
- [limited-fanout.md](recipes/limited-fanout.md)
- [promise-interop.md](recipes/promise-interop.md)
- [adapt-module.md](recipes/adapt-module.md)
- [heavy-packet-handlers.md](recipes/heavy-packet-handlers.md)

## Other

- [troubleshooting.md](troubleshooting.md)
- [branding.md](branding.md)
