--!native
local packetIDs = require(script.Parent.Parent.api.packet_ids)
local readRefs = require(script.Parent.refs)

local ref = packetIDs.ref()
local freeThread: thread?

local function functionPasser(fn, ...)
	local aquiredThread = freeThread
	freeThread = nil
	fn(...)
	freeThread = aquiredThread
end

local function yielder()
	while true do
		functionPasser(coroutine.yield())
	end
end

local function runListener(fn, ...)
	if freeThread == nil then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread :: thread)
	end

	task.spawn(freeThread :: thread, fn, ...)
end

return function(incomingBuffer: buffer, references: { [number]: unknown }?, player: Player?)
	local length = buffer.len(incomingBuffer)
	local readCursor = 0

	readRefs.set(references)

	while readCursor < length do
		if readCursor >= length then
			return
		end

		local packetId = buffer.readu8(incomingBuffer, readCursor)
		readCursor += 1

		local packet = ref[packetId]
		if not packet then
			-- Unknown ID: stop processing this batch to avoid desync / crash
			return
		end

		local value, valueLength = packet.reader(incomingBuffer, readCursor)

		if typeof(valueLength) ~= "number" or valueLength < 0 or readCursor + valueLength > length then
			return
		end

		readCursor += valueLength

		for _, listener in packet.getListeners() do
			runListener(listener, value, player)
		end
	end
end
