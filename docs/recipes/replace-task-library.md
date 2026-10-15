# Recipe: replace task.spawn / wait / delay

| Old | New |
|---|---|
| `task.spawn(fn)` | `SwTask:go(fn)` |
| `task.defer(fn)` | `SwTask:go(fn)` (or run after current work finishes via sequencing) |
| `task.wait(t)` | `SwTask:wait(t)` or `s:wait(t)` |
| `task.delay(t, fn)` | `SwTask:after(t, fn)` |
| spawn + result channel | `SwTask:run(fn):await()` |
| parallel for + counter | `SwTask:each(items):limit(n):map(fn):await()` |

Migrate one system at a time. Keep configure at boot.
