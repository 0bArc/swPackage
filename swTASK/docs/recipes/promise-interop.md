# Recipe: Promise interop

```luau
SwTask:use("Promise", Promise)

-- Promise into Job
local data = SwTask:from(Promise.try(function()
	return fetchRemote()
end)):await()

-- Job graph including Promises
local results = SwTask:joinAll({
	SwTask:run(function()
		return readCache()
	end),
	Promise.retry(request, 3),
}):await()
```

Prefer `:from` at the boundary, then stay on Jobs inside your feature.
