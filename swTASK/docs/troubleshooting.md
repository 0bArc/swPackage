# Troubleshooting

## Job await errors with "job cancelled"

Something called `:cancel()`, or a parent scope cancelled children. Check PlayerRemoving hooks and scope error paths.

## cpu work panics or silently fails with Instances

You used `:cpu()` / `:cpu` flow while touching Instances. Move that map back to the default lane.

## from(thenable) errors "expected :andThen..."

The object is not a Promise-like. Pass something with `:await`, `:expect`, or `:andThen`.

## module(name) not registered

Call `SwTask:use(name, api)` before `module`. `attach` registers `"swNET"` for you.

## Flow seems single-threaded

Default `limit` is 8, but work still shares the cooperative pool. CPU-bound safe-lane code will not magically go wider; use `:cpu()` only for pure data.

## Scope finished but background work continues

That work was started with `SwTask:go` instead of `s:go`, so it was not tracked. Use scope methods for children you want cancelled.
