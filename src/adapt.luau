--!native
--!optimize 2

--[[
	Adapt foreign modules into swTASK.

	Any module can :use(). No name gate.
	from / on turn Promise-likes and callbacks into Jobs / go-lane handlers
	so you can join work across libs under one runtime.
]]

local scheduler = require(script.Parent.runtime.scheduler)
local types = require(script.Parent.types)

local modules: { [string]: any } = {}

local adapt = {}

function adapt.use(name: string, api: any): any
	if typeof(name) ~= "string" or name == "" then
		error("swTASK: module name must be a non-empty string", 2)
	end
	if api == nil then
		error("swTASK: module api cannot be nil", 2)
	end
	modules[name] = api
	return api
end

function adapt.module(name: string): any
	if typeof(name) ~= "string" or name == "" then
		error("swTASK: module name must be a non-empty string", 2)
	end
	local api = modules[name]
	if api == nil then
		error(`swTASK: module "{name}" is not registered  -  SwTask:use("{name}", api) first`, 2)
	end
	return api
end

function adapt.modules(): { string }
	local list = {}
	for name in modules do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

function adapt.has(name: string): boolean
	return modules[name] ~= nil
end

-- Wrap any listener so work runs on the swTASK go lane (not raw task.spawn).
function adapt.on<T...>(fn: (T...) -> ()): (T...) -> ()
	return function(...)
		local pack = table.pack(...)
		scheduler.go(function()
			fn(table.unpack(pack, 1, pack.n))
		end, "adapt.on")
	end
end

adapt.listen = adapt.on

--[[
	Job from a thenable (Promise, deferred, anything with :andThen / :await).
	Prefer :await when present  -  zero extra scheduling.
]]
function adapt.from<T>(thenable: any): types.Job<T>
	return scheduler.run(function()
		if thenable == nil then
			error("swTASK:from expected a thenable", 2)
		end

		if typeof(thenable.await) == "function" then
			return thenable:await()
		end

		if typeof(thenable.expect) == "function" then
			return thenable:expect()
		end

		if typeof(thenable.andThen) ~= "function" and typeof(thenable.then_) ~= "function" then
			error("swTASK:from expected :andThen, :await, or :expect", 2)
		end

		local thread = coroutine.running()
		local settled = false
		local ok: boolean?
		local payload: any

		local function resume(success: boolean, value: any)
			if settled then
				return
			end
			settled = true
			ok = success
			payload = value
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end

		local andThen = thenable.andThen or thenable.then_
		andThen(thenable, function(value)
			resume(true, value)
		end, function(err)
			resume(false, err)
		end)

		if not settled then
			coroutine.yield()
		end

		if not ok then
			error(payload, 0)
		end
		return payload
	end, "adapt.from")
end

-- Join several Jobs (or thenables coerced via from) into one Job of results.
function adapt.joinAll(items: { any }): types.Job<{ any }>
	local jobs = table.create(#items)
	for i, item in items do
		if typeof(item) == "table" and typeof(item.await) == "function" and item.status ~= nil then
			jobs[i] = item
		else
			jobs[i] = adapt.from(item)
		end
	end
	return scheduler.join(jobs)
end

return adapt
