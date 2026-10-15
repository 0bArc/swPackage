--!native
--!optimize 2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local types = require(script.Parent.Parent.types)
local read = require(script.Parent.Parent.wire.decode)
local bufferWriter = require(script.Parent.Parent.writer.channel_writer)

local load = bufferWriter.load
local appendEncoded = bufferWriter.appendEncoded
local writePacket = bufferWriter.writePacket

local MAX_INCOMING_BUFFER = 1024 * 1024

local perPlayerReliable: { [Player]: types.channelData } = {}
local perPlayerUnreliable: { [Player]: types.channelData } = {}

local dirtyReliable: { [Player]: boolean } = {}
local dirtyUnreliable: { [Player]: boolean } = {}

-- Shared with: src/transport/client.luau (Infeasible to split this into another file)
local function create()
	return {
		cursor = 0,
		size = 256,
		references = {},
		buff = buffer.create(256),
	}
end

local function dump(channel: types.channelData): (buffer, { unknown }?)
	local cursor = channel.cursor
	local dumpBuffer = buffer.create(cursor)

	buffer.copy(dumpBuffer, 0, channel.buff, 0, cursor)

	return dumpBuffer, if #channel.references > 0 then channel.references else nil
end
-- No longer shared

local globalReliable: types.channelData = create()
local globalUnreliable: types.channelData = create()
local scratch: types.channelData = create()

local function getOrCreateChannel(map: { [Player]: types.channelData }, player: Player): types.channelData?
	if not player.Parent then
		return nil
	end

	local channel = map[player]
	if channel then
		return channel
	end

	channel = create()
	map[player] = channel
	return channel
end

local function markDirty(dirty: { [Player]: boolean }, player: Player, channel: types.channelData)
	if channel.cursor > 0 then
		dirty[player] = true
	end
end

-- TODO handle invalid data better
local function onServerEvent(player: Player, data, references)
	if typeof(data) ~= "buffer" then
		return
	end

	if buffer.len(data) > MAX_INCOMING_BUFFER then
		return
	end

	if references ~= nil and typeof(references) ~= "table" then
		return
	end

	read(data, references, player)
end

local function playerAdded(player)
	getOrCreateChannel(perPlayerReliable, player)
	getOrCreateChannel(perPlayerUnreliable, player)
end

local function playerRemoving(player)
	perPlayerReliable[player] = nil
	perPlayerUnreliable[player] = nil
	dirtyReliable[player] = nil
	dirtyUnreliable[player] = nil
end

local serverProcess = {}

function serverProcess.sendAllReliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	globalReliable = writePacket(globalReliable, id, writer, data)
end

function serverProcess.sendAllUnreliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	globalUnreliable = writePacket(globalUnreliable, id, writer, data)
end

function serverProcess.sendPlayerReliable(
	player: Player,
	id: number,
	writer: (value: any) -> (),
	data: { [string]: any }
)
	local channel = getOrCreateChannel(perPlayerReliable, player)
	if not channel then
		return
	end

	perPlayerReliable[player] = writePacket(channel, id, writer, data)
	markDirty(dirtyReliable, player, perPlayerReliable[player])
end

function serverProcess.sendPlayerUnreliable(
	player: Player,
	id: number,
	writer: (value: any) -> (),
	data: { [string]: any }
)
	local channel = getOrCreateChannel(perPlayerUnreliable, player)
	if not channel then
		return
	end

	perPlayerUnreliable[player] = writePacket(channel, id, writer, data)
	markDirty(dirtyUnreliable, player, perPlayerUnreliable[player])
end

-- Serialize once; copy into each player channel when the packet has no references.
-- With references, fall back to per-player serialization (batch-local ref indices).
function serverProcess.sendPlayersEncoded(
	players: { Player },
	id: number,
	writer: (value: any) -> (),
	data: any,
	reliable: boolean
)
	local payload, refs = bufferWriter.encodePacket(scratch, id, writer, data)
	local map = if reliable then perPlayerReliable else perPlayerUnreliable
	local dirty = if reliable then dirtyReliable else dirtyUnreliable
	local sendOne = if reliable then serverProcess.sendPlayerReliable else serverProcess.sendPlayerUnreliable

	if refs then
		for _, player in players do
			sendOne(player, id, writer, data)
		end
		return
	end

	for _, player in players do
		local channel = getOrCreateChannel(map, player)
		if channel then
			load(channel)
			appendEncoded(payload)
			map[player] = bufferWriter.export()
			markDirty(dirty, player, map[player])
		end
	end
end

function serverProcess.start()
	local reliableRemote = Instance.new("RemoteEvent")
	reliableRemote.Name = "SwNetReliable"
	reliableRemote.OnServerEvent:Connect(onServerEvent)
	reliableRemote.Parent = ReplicatedStorage

	local unreliableRemote = Instance.new("UnreliableRemoteEvent")
	unreliableRemote.Name = "SwNetUnreliable"
	unreliableRemote.OnServerEvent:Connect(onServerEvent)
	unreliableRemote.Parent = ReplicatedStorage

	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end

	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)

	RunService.Heartbeat:Connect(function()
		if globalReliable.cursor > 0 then
			local b, r = dump(globalReliable)
			reliableRemote:FireAllClients(b, r)

			globalReliable.cursor = 0
			table.clear(globalReliable.references)
		end

		if globalUnreliable.cursor > 0 then
			local b, r = dump(globalUnreliable)
			unreliableRemote:FireAllClients(b, r)

			globalUnreliable.cursor = 0
			table.clear(globalUnreliable.references)
		end

		local reliableFlush = dirtyReliable
		dirtyReliable = {}
		for player in reliableFlush do
			local channel = perPlayerReliable[player]
			if channel and channel.cursor > 0 then
				local b, r = dump(channel)
				reliableRemote:FireClient(player, b, r)

				channel.cursor = 0
				table.clear(channel.references)
			end
		end

		local unreliableFlush = dirtyUnreliable
		dirtyUnreliable = {}
		for player in unreliableFlush do
			local channel = perPlayerUnreliable[player]
			if channel and channel.cursor > 0 then
				local b, r = dump(channel)
				unreliableRemote:FireClient(player, b, r)

				channel.cursor = 0
				table.clear(channel.references)
			end
		end
	end)
end

return serverProcess
