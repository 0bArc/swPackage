--!native
--!optimize 2

--[[
	Cooperative worker pool on top of Roblox task/coroutines.
	Not OS threads  -  Luau green threads. High throughput, safe with swNET.
]]

local free: { thread } = {}
local running = 0
local maxWorkers = 64

local function yielder()
	while true do
		local fn = coroutine.yield()
		running += 1
		local ok, err = pcall(fn)
		running -= 1
		if not ok then
			warn(`[swTASK] worker error: {err}`)
		end
		table.insert(free, coroutine.running())
	end
end

local function acquire(): thread
	local t = table.remove(free)
	if t then
		return t
	end
	t = coroutine.create(yielder)
	coroutine.resume(t)
	return t
end

local pool = {}

function pool.configure(options: { maxWorkers: number? })
	if options.maxWorkers then
		maxWorkers = math.max(1, options.maxWorkers)
	end
end

function pool.spawn(fn: () -> ())
	if running >= maxWorkers then
		-- back-pressure: defer until a slot frees via task.defer chain
		task.defer(function()
			pool.spawn(fn)
		end)
		return
	end
	task.spawn(acquire(), fn)
end

function pool.defer(fn: () -> ())
	task.defer(function()
		pool.spawn(fn)
	end)
end

function pool.stats(): { running: number, free: number, maxWorkers: number }
	return {
		running = running,
		free = #free,
		maxWorkers = maxWorkers,
	}
end

return pool
