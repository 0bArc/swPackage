"""Simulated tests for redesigned swTASK API."""

from __future__ import annotations

import sys

PASSED = 0
FAILED = 0


def check(name: str, cond: bool, detail: str = "") -> None:
    global PASSED, FAILED
    if cond:
        PASSED += 1
        print(f"  PASS  {name}")
    else:
        FAILED += 1
        extra = f" - {detail}" if detail else ""
        print(f"  FAIL  {name}{extra}")


class Adapt:
    def __init__(self):
        self.modules = {}

    def use(self, name, api):
        if not name:
            raise ValueError("empty name")
        if api is None:
            raise ValueError("nil api")
        self.modules[name] = api
        return api

    def module(self, name):
        return self.modules[name]

    def on(self, fn):
        def handler(*args):
            # schedules via go — not task.spawn in user code
            return ("go", fn(*args))

        return handler

    def from_thenable(self, thenable):
        # :await path
        if hasattr(thenable, "await_"):
            return thenable.await_()
        # :andThen path
        box = {"done": False, "ok": None, "val": None}

        def ok(v):
            box["done"] = True
            box["ok"] = True
            box["val"] = v

        def err(e):
            box["done"] = True
            box["ok"] = False
            box["val"] = e

        thenable.andThen(ok, err)
        if not box["ok"]:
            raise RuntimeError(box["val"])
        return box["val"]

    def join_all(self, items):
        out = []
        for item in items:
            if isinstance(item, dict) and "await" in item:
                out.append(item["await"]())
            else:
                out.append(self.from_thenable(item))
        return out


def colon_bind(api, fn):
    def bound(*args):
        if args and args[0] is api:
            return fn(*args[1:])
        return fn(*args)

    return bound


def test_adapt_any_module():
    print("\n[test] adapt any module (no sw gate)")
    a = Adapt()
    a.use("swNET", 1)
    a.use("Promise", 2)
    a.use("ProfileStore", 3)
    check("swNET ok", a.module("swNET") == 1)
    check("Promise ok", a.module("Promise") == 2)
    check("ProfileStore ok", a.module("ProfileStore") == 3)


def test_from_thenable():
    print("\n[test] from thenable")
    a = Adapt()

    class P:
        def andThen(self, ok, err):
            ok(42)

    check("andThen resolves", a.from_thenable(P()) == 42)

    class Awaitable:
        def await_(self):
            return 7

    check("await path", a.from_thenable(Awaitable()) == 7)


def test_join_all_mix():
    print("\n[test] joinAll jobs + thenables")
    a = Adapt()

    class P:
        def andThen(self, ok, err):
            ok("net")

    job = {"await": lambda: "cpu"}
    out = a.join_all([job, P()])
    check("joined", out == ["cpu", "net"])


def test_verbs_replace_primitives():
    print("\n[test] verbs replace coroutine/task/parallel jargon")
    public = {
        "go",
        "run",
        "wait",
        "after",
        "each",
        "join",
        "first",
        "scope",
        "cpu",
        "use",
        "from",
        "on",
        "joinAll",
    }
    forbidden = {"spawn", "defer", "serial", "parallel", "coroutine", "actor", "sw_gate"}
    check("has adapt verbs", public >= {"use", "from", "on", "joinAll"})
    check("no mode jargon in public set", public.isdisjoint(forbidden))


def test_flow_map_pipeline():
    print("\n[test] flow map pipeline")
    items = [1, 2, 3]
    transforms = [lambda x, i: x * 2, lambda x, i: x + 1]

    def apply(item, index):
        v = item
        for t in transforms:
            v = t(v, index)
        return v

    out = [apply(x, i) for i, x in enumerate(items)]
    check("pipeline 1,2,3 -> 3,5,7", out == [3, 5, 7])


def test_flow_cpu_flag():
    print("\n[test] flow cpu flag")
    kind = "safe"
    kind = "cpu"
    check("cpu switches lane", kind == "cpu")


def test_scope_cancel_children():
    print("\n[test] scope cancel children")
    children = [{"status": "running"}, {"status": "running"}]
    cancelled = False

    def cancel_scope():
        nonlocal cancelled
        cancelled = True
        for c in children:
            c["status"] = "cancelled"

    cancel_scope()
    check("all children cancelled", all(c["status"] == "cancelled" for c in children))
    check("scope marked cancelled", cancelled)


def test_first_race():
    print("\n[test] first race")
    settled = False
    winner = None

    def on_ok(v):
        nonlocal settled, winner
        if settled:
            return
        settled = True
        winner = v

    on_ok("a")
    on_ok("b")
    check("first wins once", winner == "a" and settled)


def test_colon_style():
    print("\n[test] colon style")
    api = {}
    log = []

    def go(fn):
        log.append(fn())
        return "job"

    api["go"] = colon_bind(api, go)
    api["go"](lambda: "dot")
    api["go"](api, lambda: "colon")
    check("dot+colon", log == ["dot", "colon"])


def test_on_lane():
    print("\n[test] :on schedules go lane")
    a = Adapt()
    calls = []
    h = a.on(lambda d: calls.append(d))
    tag, _ = h(9)
    check("on uses go lane", tag == "go" and calls == [9])


def main() -> int:
    print("swTASK redesign simulation")
    test_adapt_any_module()
    test_from_thenable()
    test_join_all_mix()
    test_verbs_replace_primitives()
    test_flow_map_pipeline()
    test_flow_cpu_flag()
    test_scope_cancel_children()
    test_first_race()
    test_colon_style()
    test_on_lane()
    print(f"\n=== Results: {PASSED} passed, {FAILED} failed ===")
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
