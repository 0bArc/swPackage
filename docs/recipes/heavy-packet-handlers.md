# Recipe: heavy packet handlers

```luau
SwTask.swnet:attach(SwNet)

packets.placeBlock.listen(SwTask.swnet:on(function(data, player)
	if not player then
		return
	end
	if not canPlace(player, data) then
		return
	end
	commitPlace(player, data)
end))
```

Do not sleep on the bare listen callback if you care about batch latency. `:on` moves the body onto the go lane.
