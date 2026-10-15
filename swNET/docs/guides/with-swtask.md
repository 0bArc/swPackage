# With swTASK

```luau
local SwTask = require(path.to.swTASK)
local SwNet = require(path.to.swNET)

SwTask.swnet:attach(SwNet)

packets.hit.listen(SwTask.swnet:on(function(data, player)
	-- heavy logic here
end))
```

swNET owns bytes. swTASK owns jobs and cancel. Do not put `task.spawn` inside every listener when the bridge exists.
