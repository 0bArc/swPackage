# Scopes and cancel

Scopes implement structured concurrency: children belong to a parent lifetime.

## Rules of thumb

1. One scope per player session, UI modal, match, or request.
2. Start children with `s:go` / `s:run` so they are tracked.
3. On leave / close, `session:cancel()` (the scope Job's cancel path tears children down via error handlers and explicit cancel).
4. Poll `s:cancelled()` in loops.

## Failure

If the scope body throws, swTASK cancels tracked children and rejects the scope Job.

## Success

When the body returns, pending tracked children are joined before the scope Job resolves. That prevents "returned early while background go still runs" leaks for tracked children.

## Anti-pattern

```luau
-- bad: orphan spawn outside scope tracking
SwTask:scope(function(s)
	SwTask:go(function() -- not s:go, not tracked by this scope
		orphan()
	end)
end)
```

Use `s:go` so cancel reaches the child.
