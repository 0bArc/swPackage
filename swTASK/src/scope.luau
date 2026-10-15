--!native
--!optimize 2

--[[
	Structured concurrency  -  one scope owns child jobs.
	Leaving/failing/cancelling the scope cancels children.
	Replaces tangled coroutine trees.
]]

local types = require(script.Parent.types)
local scheduler = require(script.Parent.runtime.scheduler)
local flowMod = require(script.Parent.flow)
local jobMod = require(script.Parent.job)

local function openScope(): (types.Scope, { types.Job<any> }, () -> ())
	local children: { types.Job<any> } = {}
	local cancelled = false

	local scope = {} :: types.Scope

	local function track<T>(job: types.Job<T>): types.Job<T>
		table.insert(children, job)
		if cancelled then
			job:cancel()
		end
		return job
	end

	function scope.go(self, fn: () -> ())
		return track(scheduler.go(fn, "scope.go"))
	end

	function scope.run<T>(self, fn: () -> T)
		return track(scheduler.run(fn, "scope.run", "safe"))
	end

	function scope.wait(self, seconds: number)
		if cancelled then
			error("swTASK: scope cancelled", 2)
		end
		scheduler.wait(seconds)
	end

	function scope.each<T>(self, items: { T })
		return flowMod.each(items)
	end

	function scope.join<T>(self, jobs: { types.Job<T> })
		return scheduler.join(jobs):await()
	end

	function scope.cancel(self)
		cancelled = true
		for _, child in children do
			child:cancel()
		end
	end

	function scope.cancelled(self)
		return cancelled
	end

	local function close()
		-- do not auto-cancel on success; caller owns join
	end

	return scope, children, close
end

local function runScope<T>(fn: (types.Scope) -> T): types.Job<T>
	local job, ctrl = jobMod.make("scope")
	local scope, children, _close = openScope()

	scheduler.go(function()
		ctrl.setRunning()
		local ok, value = pcall(fn, scope)
		if not ok then
			scope:cancel()
			ctrl.reject(tostring(value))
			return
		end
		-- wait for tracked children still running? structured: await join of pending
		local pending = {}
		for _, child in children do
			if child.status == "pending" or child.status == "running" then
				table.insert(pending, child)
			end
		end
		if #pending > 0 then
			local joinOk, joinErr = pcall(function()
				scheduler.join(pending):await()
			end)
			if not joinOk then
				scope:cancel()
				ctrl.reject(tostring(joinErr))
				return
			end
		end
		ctrl.resolve(value)
	end)

	job:onErr(function()
		scope:cancel()
	end)

	return job
end

return {
	run = runScope,
}
