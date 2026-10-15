local bufferWriter = require(script.Parent.Parent.writer.channel_writer)
local readRefs = require(script.Parent.Parent.wire.refs)
local types = require(script.Parent.Parent.types)

local reference = bufferWriter.reference
local alloc = bufferWriter.alloc

return function(): types.dataTypeInterface<unknown>
	return {
		write = function(value: unknown)
			alloc(1)
			reference(value)
		end,

		read = function(b: buffer, cursor: number)
			local refs = readRefs.get()

			if not refs then
				return nil, 1
			end

			return refs[buffer.readu8(b, cursor)], 1
		end,
	}
end
