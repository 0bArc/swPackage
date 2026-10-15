export type JobStatus = "pending" | "running" | "ok" | "err" | "cancelled"

--[[
	WorkKind (internal policy  -  not "coroutines" / "threads"):
	  safe  Instance-safe cooperative workers (default, swNET hot path)
	  cpu   Actor workers for pure compute (no Instances)
]]
export type WorkKind = "safe" | "cpu"

export type Job<T> = {
	id: number,
	name: string,
	status: JobStatus,
	await: (self: Job<T>) -> T,
	cancel: (self: Job<T>) -> (),
	onOk: (self: Job<T>, fn: (T) -> ()) -> Job<T>,
	onErr: (self: Job<T>, fn: (string) -> ()) -> Job<T>,
}

export type Flow<T> = {
	map: <R>(self: Flow<T>, fn: (T, number) -> R) -> Flow<R>,
	forEach: (self: Flow<T>, fn: (T, number) -> ()) -> Job<()>,
	cpu: (self: Flow<T>) -> Flow<T>,
	limit: (self: Flow<T>, workers: number) -> Flow<T>,
	named: (self: Flow<T>, name: string) -> Flow<T>,
	await: <R>(self: Flow<T>) -> { R },
	collect: (self: Flow<T>) -> Job<{ T }>,
}

export type Scope = {
	go: (self: Scope, fn: () -> ()) -> Job<()>,
	run: <T>(self: Scope, fn: () -> T) -> Job<T>,
	wait: (self: Scope, seconds: number) -> (),
	each: <T>(self: Scope, items: { T }) -> Flow<T>,
	join: <T>(self: Scope, jobs: { Job<T> }) -> { T },
	cancel: (self: Scope) -> (),
	cancelled: (self: Scope) -> boolean,
}

export type SwNetBridge = {
	attach: (self: SwNetBridge, swnetModule: any) -> any,
	on: <T>(self: SwNetBridge, fn: (data: T, player: Player?) -> ()) -> (data: T, player: Player?) -> (),
	eachPlayer: <R>(
		self: SwNetBridge,
		players: { Player },
		fn: (Player, number) -> R
	) -> Job<{ R }>,
	-- aliases
	listen: <T>(self: SwNetBridge, fn: (data: T, player: Player?) -> ()) -> (data: T, player: Player?) -> (),
	mapPlayers: <R>(
		self: SwNetBridge,
		players: { Player },
		fn: (Player, number) -> R
	) -> Job<{ R }>,
}

export type SwTask = {
	-- replace task.spawn / coroutine.create
	go: (self: SwTask, fn: () -> ()) -> Job<()>,
	run: <T>(self: SwTask, fn: () -> T) -> Job<T>,
	wait: (self: SwTask, seconds: number) -> (),
	after: (self: SwTask, seconds: number, fn: () -> ()) -> Job<()>,

	-- replace manual parallel loops
	each: <T>(self: SwTask, items: { T }) -> Flow<T>,
	join: <T>(self: SwTask, jobs: { Job<T> }) -> Job<{ T }>,
	first: <T>(self: SwTask, jobs: { Job<T> }) -> Job<T>,

	-- structured concurrency (replaces ad-hoc coroutine graphs)
	scope: <T>(self: SwTask, fn: (Scope) -> T) -> Job<T>,

	-- pure compute lane (Actors under the hood)
	cpu: <T>(self: SwTask, fn: () -> T) -> Job<T>,

	configure: (self: SwTask, options: { maxWorkers: number?, cpuWorkers: number? }) -> (),

	-- adapt any module into the job graph
	use: (self: SwTask, name: string, api: any) -> any,
	module: (self: SwTask, name: string) -> any,
	modules: (self: SwTask) -> { string },
	on: <T...>(self: SwTask, fn: (T...) -> ()) -> (T...) -> (),
	listen: <T...>(self: SwTask, fn: (T...) -> ()) -> (T...) -> (),
	from: <T>(self: SwTask, thenable: any) -> Job<T>,
	joinAll: (self: SwTask, items: { any }) -> Job<{ any }>,

	-- aliases
	register: (self: SwTask, name: string, api: any) -> any,
	tool: (self: SwTask, name: string) -> any,
	tools: (self: SwTask) -> { string },

	stats: (self: SwTask) -> any,
	swnet: SwNetBridge,
}

return nil
