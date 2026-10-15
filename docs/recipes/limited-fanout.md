# Recipe: limited fanout

```luau
local snapshots = SwTask:each(Players:GetPlayers())
	:named("snapshots")
	:limit(10)
	:map(function(player, i)
		return {
			userId = player.UserId,
			pos = player.Character and player.Character:GetPivot().Position,
		}
	end)
	:await()
```

Raise `limit` only when the work is cheap and Instance-safe. Lower it for DataStore keyed loads.
