--!native
--!optimize 2

--[[
	swNET bridge  -  packet work rides swTASK, not raw task.spawn.
]]

local adapt = require(script.Parent.Parent.adapt)
local flowMod = require(script.Parent.Parent.flow)

local bridge = {}

function bridge.attach(swnetModule: any)
	adapt.use("swNET", swnetModule)
	return swnetModule
end

function bridge.on<T>(fn: (data: T, player: Player?) -> ()): (data: T, player: Player?) -> ()
	return adapt.on(fn)
end

-- alias
bridge.listen = bridge.on

function bridge.eachPlayer<R>(players: { Player }, fn: (Player, number) -> R)
	return flowMod.each(players):named("swNET.players"):map(fn):collect()
end

bridge.mapPlayers = bridge.eachPlayer

return bridge
