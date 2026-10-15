# Principles

## 1. Replace primitives, do not rename them

| Stop using | Use |
|---|---|
| `task.spawn` / `coroutine.create` | `SwTask:go` / `SwTask:run` |
| `task.wait` | `SwTask:wait` |
| `task.delay` | `SwTask:after` |
| hand-rolled parallel loops | `SwTask:each(...):map(...):await()` |
| Actor talk in app code | `SwTask:cpu` or flow `:cpu()` |
| ad hoc cancel graphs | `SwTask:scope` |

## 2. Intent over mechanism

go, run, each, join, first, scope, cpu. App code should not mention pools or coroutines.

## 3. Safe by default

Default lane is Instance-safe. Opt into cpu only for pure functions.

## 4. Structured cancel

Scopes own children. Failure or cancel tears the tree down.

## 5. Adapt any module

```luau
SwTask:use("Promise", Promise)
SwTask:from(Promise.resolve(1)):await()
```

## 6. Keep network edges thin

```luau
packet.listen(SwTask.swnet:on(handler))
```
