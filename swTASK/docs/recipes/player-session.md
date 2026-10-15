# Recipe: per-player session scope

```luau
local sessions: { [Player]: any } = {}

local function start(player: Player)
	sessions[player] = SwTask:scope(function(s)
		local profile = s:run(function()
			return loadProfile(player)
		end):await()

		s:go(function()
			replicateIntro(player, profile)
		end)

		while not s:cancelled() do
			tick(player, profile)
			s:wait(0.2)
		end
	end)
end

Players.PlayerAdded:Connect(start)

Players.PlayerRemoving:Connect(function(player)
	local job = sessions[player]
	if job then
		job:cancel()
		sessions[player] = nil
	end
end)
```
