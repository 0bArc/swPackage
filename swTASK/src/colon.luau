--!native
--!optimize 2

--[[
	Allow both:
	  SwTask.run(fn, opts)
	  SwTask:run(fn, opts)
	Colon passes the API table as arg1; strip it when detected.
]]

local function isApiTable(value: any, api: any): boolean
	return type(value) == "table" and value == api
end

local colon = {}

function colon.bind(api: any, fn: (...any) -> ...any): (...any) -> ...any
	return function(...)
		local n = select("#", ...)
		if n > 0 and isApiTable((...), api) then
			return fn(select(2, ...))
		end
		return fn(...)
	end
end

return colon
