# API reference

Colon style is preferred: `SwTask:go(fn)`, `job:await()`.

## SwTask

### configure(options)

```luau
SwTask:configure({
	maxWorkers = 64,
	cpuWorkers = 4, -- alias: actorWorkers
})
```

Sizes the cooperative pool and cpu lane. Call at boot.

### go(fn) -> Job

Fire-and-forget. Returns a Job you may ignore, cancel, or observe.

### run(fn) -> Job

Runs `fn` and captures its return value on the Job.

### wait(seconds)

Sleep. Prefer `s:wait` inside scopes.

### after(seconds, fn) -> Job

Delayed `go`.

### each(items) -> Flow

Starts a fluent batch. See Flow below.

### join(jobs) -> Job

Wait for every Job. Result order matches input order.

### first(jobs) -> Job

Resolves with the first successful Job value.

### scope(fn) -> Job

Runs `fn(scope)`. Tracks child jobs from `s:go` / `s:run`. Errors cancel children.

### cpu(fn) -> Job

Pure compute Job (no Instances).

### use(name, api) -> api

Register any module by name.

### module(name) -> api

Fetch a registered module (errors if missing).

### modules() -> { string }

Sorted list of registered names.

### on(fn) / listen(fn)

Wraps a callback so invocations schedule via `go`.

### from(thenable) -> Job

Accepts objects with `:await`, `:expect`, or `:andThen` / `:then_`.

### joinAll(items) -> Job

Items that look like Jobs (`await` + `status`) join directly. Others go through `from`.

### stats()

Pool stats, `cpuReady`, and `modules` list.

### swnet

Bridge table. See [guides/with-swnet.md](guides/with-swnet.md).

| Method | Role |
|---|---|
| `attach(SwNet)` | `use("swNET", SwNet)` |
| `on(fn)` / `listen(fn)` | packet handler on go lane |
| `eachPlayer(players, fn)` / `mapPlayers` | flow over players |

Aliases: `register`/`tool`/`tools` map to `use`/`module`/`modules`.

## Job

| Field / method | Role |
|---|---|
| `id` | numeric id |
| `name` | label |
| `status` | pending / running / ok / err / cancelled |
| `:await()` | yield until ok; errors on err/cancel |
| `:cancel()` | request cancel |
| `:onOk(fn)` | success callback (chains) |
| `:onErr(fn)` | error/cancel callback (chains) |

## Flow

Created by `SwTask:each(items)` or `s:each(items)`.

| Method | Role |
|---|---|
| `:map(fn)` | queue transform `(value, index) -> next` |
| `:forEach(fn)` | side effect Job |
| `:cpu()` | switch lane to pure compute |
| `:limit(n)` | concurrency cap (min 1) |
| `:named(name)` | job name prefix |
| `:collect()` | Job of result list |
| `:await()` | `collect():await()` |

Default limit is 8. Transforms compose in order.

## Scope

| Method | Role |
|---|---|
| `:go(fn)` | tracked go |
| `:run(fn)` | tracked run |
| `:wait(seconds)` | errors if scope already cancelled |
| `:each(items)` | flow (not auto-tracked as one child; maps spawn tracked work via scheduler) |
| `:join(jobs)` | await join immediately |
| `:cancel()` | cancel all tracked children |
| `:cancelled()` | boolean |
