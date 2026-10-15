# Flows and batching

`SwTask:each(items)` builds a Flow. Flows replace hand-rolled parallel for-loops.

## Pipeline

```luau
local view = SwTask:each(rawRows)
	:named("rows")
	:limit(16)
	:map(function(row, i)
		return normalize(row)
	end)
	:map(function(row, i)
		return enrich(row)
	end)
	:await()
```

Each `map` receives the previous stage output. Index is the original item index.

## Concurrency

`limit(n)` caps how many item bodies run at once. Use it for DataStore, HTTP, or Instance-heavy maps. Default is 8.

## forEach vs map

- `map` builds results.
- `forEach` applies side effects and returns a Job (result values are nil).

## collect vs await

`collect()` gives you the Job (attach `onOk`, cancel, compose). `await()` is shorthand for `collect():await()`.
