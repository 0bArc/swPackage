--!native
--!optimize 2

--[[
	Collects all write operations into a queue.
	When the buffer is written, it will be written in the order of the queue.

	All operations take in 2 parameters: the cursor and the value.
	Knowing this we can easily attach everything in a nice table, where
	{
		[1] = writer,
		[2] = cursor,
		[3] = value
	}

	A lot of these functions just exist as shorthand optimizations.
]]
local types = require(script.Parent.Parent.types)

local MAX_REFERENCES = 255

local current: types.channelData

local size: number
local cursor: number
local buff: buffer
local references: { [number]: unknown }

local function ensureCapacity(additionalBytes: number)
	local required = cursor + additionalBytes
	if required <= size then
		return
	end

	local newSize = math.max(size, 1)
	while newSize < required do
		newSize *= 2
	end

	local newBuffer = buffer.create(newSize)
	if cursor > 0 then
		buffer.copy(newBuffer, 0, buff, 0, cursor)
	end

	buff = newBuffer
	size = newSize
end

local function alloc(bytes: number)
	ensureCapacity(bytes)
end

local function dyn_alloc(bytes: number)
	ensureCapacity(bytes)
end

local bufferWriter = {}

bufferWriter.alloc = alloc
bufferWriter.dyn_alloc = dyn_alloc
bufferWriter.ensureCapacity = ensureCapacity
bufferWriter.MAX_REFERENCES = MAX_REFERENCES

function bufferWriter.u8(value: number)
	alloc(1)
	buffer.writeu8(buff, cursor, value)
	cursor += 1
end

-- 0.5-style no-alloc primitive: caller must alloc() first (color3, batched fields).
function bufferWriter.u8NoAlloc(value: number)
	buffer.writeu8(buff, cursor, value)
	cursor += 1
end

function bufferWriter.i8(value: number)
	alloc(1)
	buffer.writei8(buff, cursor, value)
	cursor += 1
end

-- this exists solely for the unknown and instance data type. Will likely be obselete soon enough
function bufferWriter.reference(value: any)
	local index = #references + 1
	if index > MAX_REFERENCES then
		error(`swNET: reference table exceeded {MAX_REFERENCES} entries in one batch`)
	end

	table.insert(references, value)

	buffer.writeu8(buff, cursor, index)
	cursor += 1
end

function bufferWriter.u16(value: number)
	alloc(2)
	buffer.writeu16(buff, cursor, value)
	cursor += 2
end

function bufferWriter.i16(value: number)
	alloc(2)
	buffer.writei16(buff, cursor, value)
	cursor += 2
end

function bufferWriter.u32(value: number)
	alloc(4)
	buffer.writeu32(buff, cursor, value)
	cursor += 4
end

function bufferWriter.writestring(value: string)
	buffer.writestring(buff, cursor, value)
	cursor += string.len(value)
end

function bufferWriter.i32(value: number)
	alloc(4)
	buffer.writei32(buff, cursor, value)
	cursor += 4
end

function bufferWriter.f32NoAlloc(value: number)
	buffer.writef32(buff, cursor, value)
	cursor += 4
end

function bufferWriter.f64NoAlloc(value: number)
	buffer.writef64(buff, cursor, value)
	cursor += 8
end

function bufferWriter.f32(value: number)
	alloc(4)
	buffer.writef32(buff, cursor, value)
	cursor += 4
end

function bufferWriter.f64(value: number)
	alloc(8)
	buffer.writef64(buff, cursor, value)
	cursor += 8
end

function bufferWriter.copy(value)
	buffer.copy(buff, cursor, value)
	cursor += buffer.len(value)
end

function bufferWriter.bool(val: boolean)
	alloc(1)
	buffer.writeu8(buff, cursor, if val then 1 else 0)
	cursor += 1
end

function bufferWriter.load(channel: types.channelData)
	current = channel
	size = channel.size
	cursor = channel.cursor
	references = channel.references
	buff = channel.buff
end

function bufferWriter.export()
	current.size = size
	current.cursor = cursor
	current.references = references
	current.buff = buff

	return current
end

-- 0.5 write_packet model: load channel → write id+payload → export updated channel.
-- Keeps per-channel buffers (not the broken global channel_state stub).
function bufferWriter.writePacket(
	channel: types.channelData,
	id: number,
	writer: (value: any) -> (),
	data: any
): types.channelData
	bufferWriter.load(channel)
	bufferWriter.u8(id)
	writer(data)
	return bufferWriter.export()
end

bufferWriter.write_packet = bufferWriter.writePacket

-- Encode into a scratch channel, then export an immutable payload snapshot.
-- Returns refs only when the packet used Instance/unknown fields.
function bufferWriter.encodePacket(
	scratch: types.channelData,
	id: number,
	writer: (value: any) -> (),
	data: any
): (buffer, { unknown }?)
	scratch.cursor = 0
	table.clear(scratch.references)

	bufferWriter.writePacket(scratch, id, writer, data)

	local payload = buffer.create(scratch.cursor)
	buffer.copy(payload, 0, scratch.buff, 0, scratch.cursor)

	local refs: { unknown }? = if #scratch.references > 0 then table.clone(scratch.references) else nil
	return payload, refs
end

-- Append pre-encoded bytes with no references into the active channel.
-- Packets that carry references must be re-serialized per destination (index slots are batch-local).
function bufferWriter.appendEncoded(payload: buffer)
	local payloadLen = buffer.len(payload)
	ensureCapacity(payloadLen)
	buffer.copy(buff, cursor, payload, 0, payloadLen)
	cursor += payloadLen
end

return bufferWriter
