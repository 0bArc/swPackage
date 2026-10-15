# Jobs and await

A Job is the unit of async work in swTASK. You get one from `go`, `run`, `cpu`, `after`, `join`, `first`, `scope`, `from`, flow `collect`, and similar.

## Lifecycle

1. `pending` - created, not started running yet
2. `running` - executing
3. terminal: `ok`, `err`, or `cancelled`

`await` on `ok` returns the value. On `err` or `cancelled` it errors.

## Observing without await

```luau
SwTask:run(load)
	:onOk(function(data)
		apply(data)
	end)
	:onErr(function(message)
		warn(message)
	end)
```

If the Job already finished when you attach `onOk`/`onErr`, the callback runs immediately (spawned).

## Cancel

```luau
local job = SwTask:go(longWork)
job:cancel()
```

Cancel is cooperative at the Job boundary: the controller stops resolving, waiters wake with failure, and further resolve/reject is ignored. Long loops should also check `scope:cancelled()` when inside a scope.

## Naming

Scheduler labels help debugging (`go`, `run`, `scope.go`, flow `named`). Prefer `:named` on flows that hit production metrics.
