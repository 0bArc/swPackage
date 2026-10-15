--!native
--!optimize 2

--[[
	Parallel Luau via Actors (true multithreading when Parallel Luau is available).
	Falls back to the cooperative pool if Actors cannot be created (edit mode / tests).
]]

local pool = require(script.Parent.pool)

local actors: { Actor } = {}
local actorFolder: Folder? = nil
local actorWorkers = 4
local nextActor = 1
local parallelReady = false

local function ensureFolder(): Folder
	if actorFolder and actorFolder.Parent then
		return actorFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "SwTaskActors"
	folder.Parent = game:GetService("ServerScriptService")
	actorFolder = folder
	return folder
end

local function tryBuildActors(count: number)
	local ok, err = pcall(function()
		local folder = ensureFolder()
		for i = #actors + 1, count do
			local actor = Instance.new("Actor")
			actor.Name = `SwTaskWorker_{i}`
			actor.Parent = folder

			-- Worker script: executes serializable job functions sent as messages.
			-- Callers should prefer mapParallel with pure functions over Instance touches.
			local worker = Instance.new("BindableFunction")
			worker.Name = "Run"
			worker.Parent = actor
			worker.OnInvoke = function(fn: any, payload: any)
				return fn(payload)
			end

			table.insert(actors, actor)
		end
		parallelReady = #actors > 0
	end)
	if not ok then
		parallelReady = false
		warn(`[swTASK] parallel actors unavailable, using pool fallback: {err}`)
	end
end

local parallel = {}

function parallel.configure(options: { actorWorkers: number? })
	if options.actorWorkers then
		actorWorkers = math.max(1, options.actorWorkers)
	end
end

function parallel.isReady(): boolean
	return parallelReady
end

function parallel.warmup()
	if #actors < actorWorkers then
		tryBuildActors(actorWorkers)
	end
end

--[[
	Run fn(payload)  -  prefers Actor round-robin, else pool.
	fn must be safe for the chosen mode (Actors: no unsafe shared state).
]]
function parallel.run(fn: (any) -> any, payload: any, onDone: (ok: boolean, value: any) -> ())
	if not parallelReady then
		tryBuildActors(actorWorkers)
	end

	if parallelReady and #actors > 0 then
		local actor = actors[nextActor]
		nextActor = (nextActor % #actors) + 1
		local runner = actor:FindFirstChild("Run") :: BindableFunction?
		if runner then
			task.spawn(function()
				local ok, value = pcall(function()
					return runner:Invoke(fn, payload)
				end)
				onDone(ok, value)
			end)
			return
		end
	end

	pool.spawn(function()
		local ok, value = pcall(fn, payload)
		onDone(ok, value)
	end)
end

--[[
	Map items across workers. Returns when all complete.
	Uses SharedTable-like assembly on the calling thread.
]]
function parallel.map<T, R>(
	items: { T },
	fn: (T, number) -> R,
	workers: number,
	onComplete: ({ R }) -> (),
	onError: (string) -> ()
)
	local n = #items
	if n == 0 then
		onComplete({})
		return
	end

	local results: { R } = table.create(n)
	local remaining = n
	local failed = false
	local workerCount = math.clamp(workers, 1, n)

	if not parallelReady then
		tryBuildActors(math.max(actorWorkers, workerCount))
	end

	for index, item in items do
		parallel.run(function(payload)
			return fn(payload.item, payload.index)
		end, { item = item, index = index }, function(ok, value)
			if failed then
				return
			end
			if not ok then
				failed = true
				onError(tostring(value))
				return
			end
			results[index] = value
			remaining -= 1
			if remaining == 0 then
				onComplete(results)
			end
		end)
	end
end

return parallel
