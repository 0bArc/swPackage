local RunService = game:GetService("RunService")

local clientProcess = require(script.transport.client)
local serverProcess = require(script.transport.server)
local values = require(script.sync.values)
local define_packet = require(script.api.define_packet)
local namespace = require(script.api.namespace)
local types = require(script.types)

local array = require(script.codec.array)
local bool = require(script.codec.bool)
local buff = require(script.codec.buff)
local cframe = require(script.codec.cframe)
local color3 = require(script.codec.color3)
local float32 = require(script.codec.float32)
local float64 = require(script.codec.float64)
local inst = require(script.codec.inst)
local int16 = require(script.codec.int16)
local int32 = require(script.codec.int32)
local int8 = require(script.codec.int8)
local map = require(script.codec.map)
local nothing = require(script.codec.nothing)
local optional = require(script.codec.optional)
local string = require(script.codec.string)
local struct = require(script.codec.struct)
local uint16 = require(script.codec.uint16)
local uint32 = require(script.codec.uint32)
local uint8 = require(script.codec.uint8)
local unknown = require(script.codec.unknown)
local vec2 = require(script.codec.vec2)
local vec3 = require(script.codec.vec3)

values.start()

if RunService:IsServer() then
	serverProcess.start()
else
	clientProcess.start()
end

return (
	table.freeze({
		definePacket = define_packet,
		define_packet = define_packet,
		defineNamespace = namespace,
		define_namespace = namespace,

		array = array,
		bool = bool(),
		optional = optional,
		uint8 = uint8(),
		uint16 = uint16(),
		uint32 = uint32(),
		int8 = int8(),
		int16 = int16(),
		int32 = int32(),
		float32 = float32(),
		float64 = float64(),
		cframe = cframe(),
		color3 = color3(),
		string = string(),
		vec2 = vec2(),
		vec3 = vec3(),
		buff = buff(),
		struct = struct,
		map = map,
		inst = inst(),
		unknown = unknown(),
		nothing = nothing(),
	}) :: any
) :: types.SwNet
