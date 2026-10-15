local bufferWriter = require(script.Parent.Parent.writer.channel_writer)
local types = require(script.Parent.Parent.types)

local i16 = bufferWriter.i16

local int16 = {
	write = i16,

	read = function(b: buffer, cursor: number)
		return buffer.readi16(b, cursor), 2
	end,
}

return function(): types.dataTypeInterface<number>
	return int16
end
