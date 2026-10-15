--!native
--!optimize 2

local types = require(script.Parent.types)

local nextId = 0

local function makeJob<T>(name: string): (types.Job<T>, {
	resolve: (T) -> (),
	reject: (string) -> (),
	setRunning: () -> (),
	isCancelled: () -> boolean,
})
	nextId += 1

	local status: types.JobStatus = "pending"
	local result: T? = nil
	local errMsg: string? = nil
	local waiters: { thread } = {}
	local okFns: { (T) -> () } = {}
	local errFns: { (string) -> () } = {}
	local cancelled = false

	local job: types.Job<T> = {
		id = nextId,
		name = name,
		status = status,
		await = nil :: any,
		cancel = nil :: any,
		onOk = nil :: any,
		onErr = nil :: any,
	}

	local function setStatus(s: types.JobStatus)
		status = s
		job.status = s
	end

	local function wake(ok: boolean)
		local threads = waiters
		waiters = {}
		for _, t in threads do
			if ok then
				task.spawn(t, true, result)
			else
				task.spawn(t, false, errMsg)
			end
		end
	end

	function job.await(_self: types.Job<T>): T
		if status == "ok" then
			return result :: T
		elseif status == "err" then
			error(errMsg or "swTASK job failed", 2)
		elseif status == "cancelled" then
			error("swTASK: job cancelled", 2)
		end

		table.insert(waiters, coroutine.running())
		local okResume, value = coroutine.yield()
		if okResume then
			return value :: T
		end
		error(value or "swTASK job failed", 2)
	end

	function job.cancel(_self: types.Job<T>)
		if status == "ok" or status == "err" or status == "cancelled" then
			return
		end
		cancelled = true
		setStatus("cancelled")
		errMsg = "swTASK: job cancelled"
		wake(false)
	end

	function job.onOk(_self: types.Job<T>, fn: (T) -> ()): types.Job<T>
		if status == "ok" then
			task.spawn(fn, result :: T)
		elseif status == "pending" or status == "running" then
			table.insert(okFns, fn)
		end
		return job
	end

	function job.onErr(_self: types.Job<T>, fn: (string) -> ()): types.Job<T>
		if status == "err" or status == "cancelled" then
			task.spawn(fn, errMsg or "error")
		elseif status == "pending" or status == "running" then
			table.insert(errFns, fn)
		end
		return job
	end

	local controller = {
		resolve = function(value: T)
			if cancelled or status == "ok" or status == "err" or status == "cancelled" then
				return
			end
			result = value
			setStatus("ok")
			for _, fn in okFns do
				task.spawn(fn, value)
			end
			wake(true)
		end,
		reject = function(message: string)
			if cancelled or status == "ok" or status == "err" or status == "cancelled" then
				return
			end
			errMsg = message
			setStatus("err")
			for _, fn in errFns do
				task.spawn(fn, message)
			end
			wake(false)
		end,
		setRunning = function()
			if not cancelled and status == "pending" then
				setStatus("running")
			end
		end,
		isCancelled = function()
			return cancelled
		end,
	}

	return job, controller
end

return {
	make = makeJob,
}
