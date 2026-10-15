# Recipe: adapt a foreign module

Register any library with `:use`, turn its async into Jobs with `:from` / `:on`, and join it with swTASK work.

Example: a small HTTP helper that returns Promise-likes (same pattern works for ProfileStore, Promise, custom loaders).

```luau
local SwTask = require(path.to.swTASK)
local Http = require(path.to.Http) -- your module

-- 1. register under a stable name
SwTask:use("Http", Http)

-- later, anywhere:
local Http = SwTask:module("Http")

-- 2. callbacks -> go lane (no task.spawn in app code)
Http.onResponse:Connect(SwTask:on(function(status, body)
	handleResponse(status, body)
end))

-- 3. thenable / Promise return -> Job
local job = SwTask:from(Http.get("https://example.com/api/ping"))

job:onOk(function(body)
	print(body)
end)

job:onErr(function(err)
	warn(err)
end)

local body = job:await()

-- 4. join Http + local Jobs in one graph
local results = SwTask:joinAll({
	SwTask:run(function()
		return readLocalCache()
	end),
	Http.get("https://example.com/api/config"), -- coerced via :from
}):await()

local cache, config = results[1], results[2]
```

## Inside a player scope

```luau
SwTask:use("Http", Http)

SwTask:scope(function(s)
	local config = SwTask:from(Http.get(CONFIG_URL)):await()

	s:go(function()
		applyConfig(config)
	end)

	-- if the scope Job is cancelled, prefer short Http calls
	-- and check s:cancelled() before applying side effects
	if s:cancelled() then
		return
	end
end)
```

## Checklist

1. `SwTask:use("Name", api)` once at boot  
2. Fetch with `SwTask:module("Name")` when you want a single lookup point  
3. Event surfaces: wrap with `SwTask:on`  
4. Promise / `:andThen` / `:await` returns: `SwTask:from`  
5. Mix libraries with `SwTask:joinAll`  

`:use` accepts any name. There is no `sw*` gate.
