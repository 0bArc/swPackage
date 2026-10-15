# Usage

```luau
local SwTask = require(path.to.swTASK)

SwTask:configure({ maxWorkers = 64, cpuWorkers = 4 })

SwTask:go(function()
	warmup()
end)

local value = SwTask:run(function()
	return load()
end):await()

SwTask:wait(0.1)

SwTask:after(1, function()
	pulse()
end)

local scores = SwTask:each(players)
	:limit(8)
	:map(function(player, i)
		return score(player)
	end)
	:await()

local baked = SwTask:each(chunks):cpu():map(bake):await()

SwTask:scope(function(s)
	s:go(prefetch)
	return s:run(fetch):await()
end):await()

SwTask:use("Promise", Promise)
local n = SwTask:from(Promise.resolve(1)):await()

Remote.OnServerEvent:Connect(SwTask:on(function(player, payload)
	handle(player, payload)
end))
```

With swNET:

```luau
SwTask.swnet:attach(SwNet)
packets.ping.listen(SwTask.swnet:on(function(data, player)
	handle(data, player)
end))
```

Full walkthrough: [tutorial.md](tutorial.md). Method details: [api.md](api.md).
