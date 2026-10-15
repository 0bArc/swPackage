# Safe lane vs cpu lane

## Safe (default)

May touch Instances, players, remotes (through your own code), and normal Roblox APIs. This is the right default for gameplay.

## cpu

For pure functions: tables, numbers, strings, buffers you already hold. Backed by the parallel/Actor path when configured.

```luau
SwTask:cpu(function()
	return simulate(stateTable)
end)
```

Flow form:

```luau
SwTask:each(parts):cpu():map(processPart):await()
```

## Checklist before `:cpu()`

- No `Instance` methods or properties
- No `Players`, `Workspace`, or service calls
- Inputs are plain data already copied onto the safe side

Wrong lane choice is a logic bug, not a style issue.
