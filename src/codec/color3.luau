--!native
--!optimize 2
--[[
	Color3 as 3×u8 RGB (3 bytes). Same wire layout as ByteNet 0.5.
	R/G/B are Color3 components in 0..1; written as 0..255.
]]
local bufferWriter = require(script.Parent.Parent.writer.channel_writer)
local types = require(script.Parent.Parent.types)

local alloc = bufferWriter.alloc
local u8NoAlloc = bufferWriter.u8NoAlloc

local color3 = {
	length = 3,

	write = function(input: Color3)
		alloc(3)
		u8NoAlloc(input.R * 255)
		u8NoAlloc(input.G * 255)
		u8NoAlloc(input.B * 255)
	end,

	read = function(b: buffer, cursor: number)
		return Color3.fromRGB(
			buffer.readu8(b, cursor),
			buffer.readu8(b, cursor + 1),
			buffer.readu8(b, cursor + 2)
		),
			3
	end,
}

return function(): types.dataTypeInterface<Color3>
	return color3
end
