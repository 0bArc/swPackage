# Recipe: DataStore profiles with swTASK

Load on join, save on leave, cap concurrent DataStore calls with `:each():limit()`, cancel in-flight work when the player leaves.

```luau
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local SwTask = require(path.to.swTASK)

local store = DataStoreService:GetDataStore("PlayerProfiles_v1")
local sessions: { [Player]: any } = {}
local profiles: { [Player]: { coins: number, xp: number } } = {}

local DEFAULT = { coins = 0, xp = 0 }

local function keyFor(player: Player): string
	return `p_{player.UserId}`
end

local function loadProfile(player: Player)
	local key = keyFor(player)
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		error(`GetAsync failed: {data}`)
	end
	if typeof(data) ~= "table" then
		return table.clone(DEFAULT)
	end
	return data :: { coins: number, xp: number }
end

local function saveProfile(player: Player, profile: { coins: number, xp: number })
	local key = keyFor(player)
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(_old)
			return {
				coins = profile.coins,
				xp = profile.xp,
			}
		end)
	end)
	if not ok then
		error(`UpdateAsync failed: {err}`)
	end
end

local function startSession(player: Player)
	sessions[player] = SwTask:scope(function(s)
		local profile = s:run(function()
			return loadProfile(player)
		end):await()

		profiles[player] = profile

		-- optional: prefetch related keys with a tight limit
		local extraKeys = { `p_{player.UserId}_meta` }
		s:each(extraKeys)
			:named("profileExtras")
			:limit(2)
			:map(function(key, _i)
				local ok, data = pcall(function()
					return store:GetAsync(key)
				end)
				return if ok then data else nil
			end)
			:await()

		while not s:cancelled() do
			-- game tick; mutate profiles[player] in your systems
			s:wait(1)
		end
	end)

	sessions[player]:onErr(function(message)
		warn(`[profile] {player.Name}: {message}`)
	end)
end

Players.PlayerAdded:Connect(startSession)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	local profile = profiles[player]

	if session then
		session:cancel()
		sessions[player] = nil
	end

	if profile then
		-- save outside the cancelled scope so leave still persists
		SwTask:run(function()
			saveProfile(player, profile)
		end):onErr(function(message)
			warn(`[profile save] {player.Name}: {message}`)
		end)
		profiles[player] = nil
	end
end)

game:BindToClose(function()
	local list = Players:GetPlayers()
	SwTask:each(list)
		:named("shutdownSave")
		:limit(4) -- stay under DataStore budget
		:map(function(player, _i)
			local profile = profiles[player]
			if profile then
				saveProfile(player, profile)
			end
			local session = sessions[player]
			if session then
				session:cancel()
			end
			return true
		end)
		:await()
end)
```

## Why this shape

| Piece | Role |
|---|---|
| `s:run(loadProfile)` | load is a Job; scope cancel can race it cleanly |
| `:limit(2)` / `:limit(4)` | DataStore has request budgets; do not fan out unbounded |
| `session:cancel()` on leave | stops the session loop; in-flight load result is ignored if cancelled |
| save **after** cancel | leave must still write; do not put the only save inside a cancelled loop |
| `BindToClose` + `:each():limit(4)` | flush everyone without spawning one raw task per player |

## Notes

- Keep DataStore work on the **safe** lane (default). Never `:cpu()` around `GetAsync` / `UpdateAsync`.
- Retry policy: wrap `pcall` yourself or use `:from` with a Promise retry helper if you already have one.
- Studio has its own DataStore limits; test `limit` values on a live-like server size.
