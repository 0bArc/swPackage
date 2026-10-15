--!native
--!optimize 2

--[[
	swTASK  -  structured concurrency.

	Design:
	  1. Never call coroutine / task.spawn / Actors yourself  -  use swTASK verbs.
	  2. safe work by default (Instance + network friendly).
	  3. cpu() only for pure compute.
	  4. Scopes own children; cancel is hierarchical.
	  5. Colon-first: SwTask:go(fn), job:await()
	  6. :use / :from / :on adapt any module into the same job graph.
]]

local types = require(script.types)
local adapt = require(script.adapt)
local scheduler = require(script.runtime.scheduler)
local pool = require(script.runtime.pool)
local parallel = require(script.runtime.parallel)
local flowMod = require(script.flow)
local scopeMod = require(script.scope)
local swnetBridge = require(script.bridge.swnet)
local colon = require(script.colon)

local SwTask = {}

local function configure(options: { maxWorkers: number?, cpuWorkers: number?, actorWorkers: number? })
	scheduler.configure(options)
end

local function go(fn: () -> ())
	return scheduler.go(fn)
end

local function run<T>(fn: () -> T)
	return scheduler.run(fn)
end

local function wait(seconds: number)
	scheduler.wait(seconds)
end

local function after(seconds: number, fn: () -> ())
	return scheduler.after(seconds, fn)
end

local function each<T>(items: { T })
	return flowMod.each(items)
end

local function join<T>(jobs: { types.Job<T> })
	return scheduler.join(jobs)
end

local function first<T>(jobs: { types.Job<T> })
	return scheduler.first(jobs)
end

local function scope<T>(fn: (types.Scope) -> T)
	return scopeMod.run(fn)
end

local function cpu<T>(fn: () -> T)
	return scheduler.cpu(fn)
end

local function use(name: string, api: any)
	return adapt.use(name, api)
end

local function module(name: string)
	return adapt.module(name)
end

local function modules()
	return adapt.modules()
end

local function on<T...>(fn: (T...) -> ())
	return adapt.on(fn)
end

local function from<T>(thenable: any)
	return adapt.from(thenable)
end

local function joinAll(items: { any })
	return adapt.joinAll(items)
end

local function stats()
	return {
		pool = pool.stats(),
		cpuReady = parallel.isReady(),
		modules = adapt.modules(),
	}
end

SwTask.configure = colon.bind(SwTask, configure)
SwTask.go = colon.bind(SwTask, go)
SwTask.run = colon.bind(SwTask, run)
SwTask.wait = colon.bind(SwTask, wait)
SwTask.after = colon.bind(SwTask, after)
SwTask.each = colon.bind(SwTask, each)
SwTask.join = colon.bind(SwTask, join)
SwTask.first = colon.bind(SwTask, first)
SwTask.scope = colon.bind(SwTask, scope)
SwTask.cpu = colon.bind(SwTask, cpu)
SwTask.use = colon.bind(SwTask, use)
SwTask.module = colon.bind(SwTask, module)
SwTask.modules = colon.bind(SwTask, modules)
SwTask.on = colon.bind(SwTask, on)
SwTask.listen = colon.bind(SwTask, on)
SwTask.from = colon.bind(SwTask, from)
SwTask.joinAll = colon.bind(SwTask, joinAll)
SwTask.stats = colon.bind(SwTask, stats)

-- old names → adapter (no sw exclusivity)
SwTask.register = SwTask.use
SwTask.tool = SwTask.module
SwTask.tools = SwTask.modules

local swnet = {}
swnet.attach = colon.bind(swnet, swnetBridge.attach)
swnet.on = colon.bind(swnet, swnetBridge.on)
swnet.listen = colon.bind(swnet, swnetBridge.listen)
swnet.eachPlayer = colon.bind(swnet, swnetBridge.eachPlayer)
swnet.mapPlayers = colon.bind(swnet, swnetBridge.mapPlayers)
SwTask.swnet = table.freeze(swnet)

return (table.freeze(SwTask) :: any) :: types.SwTask
