# Using swTASK with swNET

## Attach

```luau
local SwNet = require(path.to.swNET)
SwTask.swnet:attach(SwNet) -- also SwTask:use("swNET", SwNet)
```

## Listeners

```luau
packets.hit.listen(SwTask.swnet:on(function(data, player)
	validateAndApply(player, data)
end))
```

Why: inbound decode should finish fast. Heavy validation / Instance work runs as swTASK jobs.

## Per player maps

```luau
SwTask.swnet:eachPlayer(Players:GetPlayers(), function(player, i)
	return buildSnapshot(player)
end):await()
```

Same as a named flow over the player list.

## Split responsibilities

| Library | Owns |
|---|---|
| swNET | encode, batch, remotes, codecs |
| swTASK | jobs, cancel, fanout, adapting other async |
