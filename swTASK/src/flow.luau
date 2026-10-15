--!native
--!optimize 2

--[[
	Fluent batch work  -  replaces hand-rolled parallel for-loops.

	  SwTask:each(items):map(fn):await()
	  SwTask:each(items):cpu():limit(16):map(heavy):await()
]]

local types = require(script.Parent.types)
local scheduler = require(script.Parent.runtime.scheduler)

local function makeFlow<T>(items: { T }): types.Flow<T>
	local kind: types.WorkKind = "safe"
	local workers = 8
	local name = "each"
	local transforms: { (any, number) -> any } = {}

	local flow = {} :: any

	function flow.cpu(self)
		kind = "cpu"
		return self
	end

	function flow.limit(self, n: number)
		workers = math.max(1, n)
		return self
	end

	function flow.named(self, n: string)
		name = n
		return self
	end

	function flow.map(self, fn: (any, number) -> any)
		table.insert(transforms, fn)
		return self
	end

	local function apply(item: any, index: number): any
		local value = item
		for _, step in transforms do
			value = step(value, index)
		end
		return value
	end

	function flow.forEach(self, fn: (any, number) -> ())
		return scheduler.map(items, function(item, index)
			fn(apply(item, index), index)
			return nil
		end, kind, workers, name .. ".forEach")
	end

	function flow.collect(self)
		if #transforms == 0 then
			return scheduler.run(function()
				return items
			end, name .. ".collect", kind)
		end
		return scheduler.map(items, apply, kind, workers, name)
	end

	function flow.await(self)
		return self:collect():await()
	end

	return flow :: types.Flow<T>
end

return {
	each = makeFlow,
}
