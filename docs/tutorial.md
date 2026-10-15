# Tutorial

This walkthrough migrates a small system from raw `task` calls to swTASK, then adds scopes, flows, adapters, and swNET.

## 0. Install

Put swTASK on a Rojo / Wally path and require the package root (the folder with `init.luau`):

```luau
local SwTask = require(ReplicatedStorage.Packages.swTASK)
```

Optional boot config (call once early):

```luau
SwTask:configure({
	maxWorkers = 64, -- cooperative pool size
	cpuWorkers = 4,  -- pure compute lane
})
```

## 1. Replace spawn / wait / delay

Before:

```luau
task.spawn(function()
	task.wait(0.2)
	doWork()
end)

task.delay(1, function()
	pulse()
end)
```

After:

```luau
SwTask:go(function()
	SwTask:wait(0.2)
	doWork()
end)

SwTask:after(1, function()
	pulse()
end)
```

`go` starts work. You can ignore the Job, or keep it to `:cancel()` / `:onErr()`.

## 2. Work that returns a value

```luau
local job = SwTask:run(function()
	return Players:GetPlayers()
end)

job:onOk(function(list)
	print(#list)
end)

local list = job:await() -- yields until ok, or errors on err/cancel
```

Job statuses: `pending`, `running`, `ok`, `err`, `cancelled`.

## 3. Batch a list (Flow)

Before: a for-loop of `task.spawn` with manual counters.

After:

```luau
local results = SwTask:each(userIds)
	:named("loadProfiles")
	:limit(8)
	:map(function(userId, index)
		return loadProfile(userId)
	end)
	:await()
```

- `map` chains transforms (each sees the previous output).
- `limit` caps concurrency (default 8).
- `named` labels jobs for debugging.
- `forEach` is side effects only; `collect` returns a Job of the list; `await` is `collect():await()`.

## 4. Pure compute lane

Default work is Instance-safe. For pure tables / math, mark cpu:

```luau
local out = SwTask:each(chunks)
	:cpu()
	:map(function(chunk, i)
		return bakeNav(chunk) -- no Instances inside
	end)
	:await()

-- or one shot
local hash = SwTask:cpu(function()
	return digest(blob)
end):await()
```

If you touch Instances on the cpu lane, you will have a bad day. Stay on the default lane when unsure.

## 5. Join and race

```luau
local a = SwTask:run(loadA)
local b = SwTask:run(loadB)

local both = SwTask:join({ a, b }):await() -- { aResult, bResult }
local winner = SwTask:first({ a, b }):await() -- first success
```

`first` does not auto-cancel losers. Put races inside a scope if you need teardown.

## 6. Scopes (structured cancel)

A scope tracks child jobs. If the scope function errors, children cancel. You can cancel explicitly.

```luau
local session = SwTask:scope(function(s)
	s:go(function()
		streamHints(player)
	end)

	local profile = s:run(function()
		return loadProfile(player)
	end):await()

	while not s:cancelled() do
		tickSession(player, profile)
		s:wait(0.1)
	end
end)

Players.PlayerRemoving:Connect(function(leaving)
	if leaving == player then
		session:cancel()
	end
end)
```

Scope methods: `s:go`, `s:run`, `s:wait`, `s:each`, `s:join`, `s:cancel`, `s:cancelled`.

When the scope body returns, swTASK waits for still-running tracked children before resolving the scope Job. Body errors cancel children and reject the scope Job.

## 7. Adapt other modules

Any module can register. No name prefix rule.

```luau
SwTask:use("Promise", Promise)
SwTask:use("ProfileStore", ProfileStore)

local Promise = SwTask:module("Promise")

-- thenable -> Job (:await / :expect / :andThen)
local value = SwTask:from(Promise.resolve(10)):await()

-- mix Jobs and thenables
local bag = SwTask:joinAll({
	SwTask:run(loadLocal),
	Promise.resolve(remote),
}):await()

-- any callback scheduled on the go lane
RemoteEvent.OnServerEvent:Connect(SwTask:on(function(player, payload)
	ingest(player, payload)
end))
```

Aliases still work: `register` = `use`, `tool` = `module`, `tools` = `modules`, `listen` = `on`.

## 8. Pair with swNET

```luau
local SwNet = require(path.to.swNET)
SwTask.swnet:attach(SwNet)

packets.move.listen(SwTask.swnet:on(function(data, player)
	applyMove(player, data)
end))

SwTask.swnet:eachPlayer(Players:GetPlayers(), function(player, i)
	return snapshot(player)
end):await()
```

Keep the decode / listen edge thin. Put heavy logic in `:on` so it rides the swTASK pool instead of blocking the inbound batch.

## 9. Stats

```luau
print(SwTask:stats())
-- pool stats, cpuReady, registered module names
```

## What you should be able to do now

- Ship features without calling `task.spawn` in app code
- Cancel per-player work on leave via scopes
- Fan out with `:each():limit()`
- Pull Promise results into the same graph with `:from` / `:joinAll`
- Attach swNET listeners through `SwTask.swnet:on`

Next: [guides/](index.md) for deeper topics, or [api.md](api.md) for signatures.
