# Recipe: sendToList party members

```luau
packets.invite.sendToList({
	from = player.UserId,
	partyId = party.id,
}, party:getPlayers())
```

When the payload has no `inst`/`unknown`, swNET encodes once and appends bytes per channel.
