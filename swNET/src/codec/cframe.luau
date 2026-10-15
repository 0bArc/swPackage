local bufferWriter = require(script.Parent.Parent.writer.channel_writer)
local types = require(script.Parent.Parent.types)

local f32NoAlloc = bufferWriter.f32NoAlloc
local alloc = bufferWriter.alloc

-- 24-byte axis-angle vector format: position xyz + (axis * angle) xyz
local cframe = {
	read = function(b: buffer, cursor: number)
		local x = buffer.readf32(b, cursor)
		local y = buffer.readf32(b, cursor + 4)
		local z = buffer.readf32(b, cursor + 8)
		local rx = buffer.readf32(b, cursor + 12)
		local ry = buffer.readf32(b, cursor + 16)
		local rz = buffer.readf32(b, cursor + 20)

		local rotationVector = Vector3.new(rx, ry, rz)
		local angle = rotationVector.Magnitude

		local rotation = if angle < 1e-6
			then CFrame.new()
			else CFrame.fromAxisAngle(rotationVector / angle, angle)

		return rotation + Vector3.new(x, y, z), 24
	end,
	write = function(value: CFrame)
		local x, y, z = value.X, value.Y, value.Z

		local axis, angle = value:ToAxisAngle()
		local rotationVector = axis * angle

		alloc(24)
		f32NoAlloc(x)
		f32NoAlloc(y)
		f32NoAlloc(z)
		f32NoAlloc(rotationVector.X)
		f32NoAlloc(rotationVector.Y)
		f32NoAlloc(rotationVector.Z)
	end,
}

return function(): types.dataTypeInterface<CFrame>
	return cframe
end
