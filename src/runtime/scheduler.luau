--!native
--!optimize 2

local jobMod = require(script.Parent.Parent.job)
local types = require(script.Parent.Parent.types)
local pool = require(script.Parent.pool)
local parallel = require(script.Parent.parallel)

local scheduler = {}

function scheduler.configure(options: { maxWorkers: number?, cpuWorkers: number?, actorWorkers: number? })
	pool.configure({ maxWorkers = options.maxWorkers })
	local cpu = options.cpuWorkers or options.actorWorkers
	parallel.configure({ actorWorkers = cpu })
	if cpu then
		parallel.warmup()
	end
end

local function executeJob<T>(fn: () -> T, name: string, kind: types.WorkKind): types.Job<T>
	local job, ctrl = jobMod.make(name)

	local function finish()
		if ctrl.isCancelled() then
			return
		end
		ctrl.setRunning()
		local ok, value = pcall(fn)
		if ctrl.isCancelled() then
			return
		end
		if ok then
			ctrl.resolve(value)
		else
			ctrl.reject(tostring(value))
		end
	end

	if kind == "cpu" then
		parallel.run(function(_payload)
			return fn()
		end, nil, function(ok, value)
			if ctrl.isCancelled() then
				return
			end
			ctrl.setRunning()
			if ok then
				ctrl.resolve(value)
			else
				ctrl.reject(tostring(value))
			end
		end)
	else
		pool.spawn(finish)
	end

	return job
end

function scheduler.go(fn: () -> (), name: string?): types.Job<()>
	return executeJob(function()
		fn()
		return nil :: any
	end, name or "go", "safe")
end

function scheduler.run<T>(fn: () -> T, name: string?, kind: types.WorkKind?): types.Job<T>
	return executeJob(fn, name or "run", kind or "safe")
end

function scheduler.cpu<T>(fn: () -> T, name: string?): types.Job<T>
	return executeJob(fn, name or "cpu", "cpu")
end

function scheduler.wait(seconds: number)
	task.wait(seconds)
end

function scheduler.after(seconds: number, fn: () -> (), name: string?): types.Job<()>
	local job, ctrl = jobMod.make(name or "after")
	task.delay(seconds, function()
		if ctrl.isCancelled() then
			return
		end
		ctrl.setRunning()
		local ok, err = pcall(fn)
		if ctrl.isCancelled() then
			return
		end
		if ok then
			ctrl.resolve(nil :: any)
		else
			ctrl.reject(tostring(err))
		end
	end)
	return job
end

function scheduler.map<T, R>(
	items: { T },
	fn: (T, number) -> R,
	kind: types.WorkKind,
	workers: number,
	name: string
): types.Job<{ R }>
	local job, ctrl = jobMod.make(name)
	local workerCount = math.max(1, workers)

	if kind == "cpu" then
		parallel.map(items, fn, workerCount, function(results)
			if not ctrl.isCancelled() then
				ctrl.setRunning()
				ctrl.resolve(results)
			end
		end, function(err)
			if not ctrl.isCancelled() then
				ctrl.reject(err)
			end
		end)
		return job
	end

	pool.spawn(function()
		if ctrl.isCancelled() then
			return
		end
		ctrl.setRunning()

		local n = #items
		local results: { R } = table.create(n)
		if n == 0 then
			ctrl.resolve(results)
			return
		end

		local remaining = n
		local failed = false
		local inflight = 0
		local nextIndex = 1
		local limit = math.clamp(workerCount, 1, n)

		local function pump()
			while inflight < limit and nextIndex <= n and not failed and not ctrl.isCancelled() do
				local index = nextIndex
				nextIndex += 1
				inflight += 1

				pool.spawn(function()
					if failed or ctrl.isCancelled() then
						inflight -= 1
						return
					end
					local ok, value = pcall(fn, items[index], index)
					inflight -= 1
					if not ok then
						failed = true
						ctrl.reject(tostring(value))
						return
					end
					results[index] = value
					remaining -= 1
					if remaining == 0 then
						ctrl.resolve(results)
					else
						pump()
					end
				end)
			end
		end

		pump()
	end)

	return job
end

function scheduler.join<T>(jobs: { types.Job<T> }): types.Job<{ T }>
	local job, ctrl = jobMod.make("join")
	pool.spawn(function()
		ctrl.setRunning()
		local results: { T } = table.create(#jobs)
		local okCollect, err = pcall(function()
			for i, j in jobs do
				results[i] = j:await()
			end
		end)
		if okCollect then
			ctrl.resolve(results)
		else
			ctrl.reject(tostring(err))
		end
	end)
	return job
end

function scheduler.first<T>(jobs: { types.Job<T> }): types.Job<T>
	local job, ctrl = jobMod.make("first")
	local n = #jobs
	if n == 0 then
		ctrl.reject("swTASK:first needs at least one job")
		return job
	end

	local settled = false
	local failed = 0

	for _, j in jobs do
		j:onOk(function(value)
			if settled or ctrl.isCancelled() then
				return
			end
			settled = true
			ctrl.setRunning()
			for _, other in jobs do
				if other ~= j then
					other:cancel()
				end
			end
			ctrl.resolve(value)
		end)

		j:onErr(function(err)
			if settled or ctrl.isCancelled() then
				return
			end
			failed += 1
			if failed >= n then
				ctrl.reject(err)
			end
		end)
	end

	return job
end

return scheduler
