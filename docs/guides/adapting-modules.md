# Adapting modules

`adapt.luau` is the open registry and interop layer (replacing the old sw-only gate).

## Registry

```luau
SwTask:use("Promise", Promise)
SwTask:use("swNET", SwNet)

assert(SwTask:module("Promise") == Promise)
print(table.concat(SwTask:modules(), ", "))
```

Any string name is allowed. Empty names and nil apis error.

## from(thenable)

Resolution order:

1. `:await()` if present
2. `:expect()` if present
3. `:andThen` / `:then_` with success/error callbacks, yielding the Job runner until settled

## on(fn)

Packs varargs, schedules `go`, then calls your function. Use for remotes, signals, and Bindables so app code does not call `task.spawn`.

## joinAll

Detects Jobs via `await` + `status`. Everything else goes through `from`. Result is one Job of an array.
