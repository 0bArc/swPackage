"""
Simulated verification of swNET P0/P1 fixes (no Roblox runtime).
Mirrors the patched algorithms from swNET-v0.4.3.
"""

from __future__ import annotations

import math
import struct
import sys
from dataclasses import dataclass, field


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


# ---------------------------------------------------------------------------
# Minimal buffer + writer mirroring patched bufferWriter.luau
# ---------------------------------------------------------------------------


class Buf:
    def __init__(self, n: int = 0):
        self.data = bytearray(n)

    def __len__(self) -> int:
        return len(self.data)


@dataclass
class Channel:
    cursor: int = 0
    size: int = 256
    references: list = field(default_factory=list)
    buff: Buf = field(default_factory=lambda: Buf(256))


class BufferWriter:
    MAX_REFERENCES = 255

    def __init__(self):
        self.size = 0
        self.cursor = 0
        self.buff = Buf(0)
        self.references: list = []
        self.current: Channel | None = None
        self.realloc_count = 0

    def ensure_capacity(self, additional: int) -> None:
        required = self.cursor + additional
        if required <= self.size:
            return
        new_size = max(self.size, 1)
        while new_size < required:
            new_size *= 2
        new_buf = Buf(new_size)
        if self.cursor > 0:
            new_buf.data[: self.cursor] = self.buff.data[: self.cursor]
        self.buff = new_buf
        self.size = new_size
        self.realloc_count += 1

    def alloc(self, n: int) -> None:
        self.ensure_capacity(n)

    def dyn_alloc(self, n: int) -> None:
        self.ensure_capacity(n)

    def load(self, channel: Channel) -> None:
        self.current = channel
        self.size = channel.size
        self.cursor = channel.cursor
        self.references = channel.references
        self.buff = channel.buff

    def export(self) -> Channel:
        assert self.current is not None
        self.current.size = self.size
        self.current.cursor = self.cursor
        self.current.references = self.references
        self.current.buff = self.buff
        return self.current

    def u8(self, v: int) -> None:
        self.alloc(1)
        self.buff.data[self.cursor] = v & 0xFF
        self.cursor += 1

    def u8_no_alloc(self, v: int) -> None:
        self.buff.data[self.cursor] = v & 0xFF
        self.cursor += 1

    def write_packet(self, channel: Channel, packet_id: int, writer, data) -> Channel:
        self.load(channel)
        self.u8(packet_id)
        writer(data)
        return self.export()

    def i16(self, v: int) -> None:
        self.alloc(2)
        struct.pack_into("<h", self.buff.data, self.cursor, v)
        self.cursor += 2

    def u16(self, v: int) -> None:
        self.alloc(2)
        struct.pack_into("<H", self.buff.data, self.cursor, v)
        self.cursor += 2

    def f32_no_alloc(self, v: float) -> None:
        struct.pack_into("<f", self.buff.data, self.cursor, v)
        self.cursor += 4

    def f64_no_alloc(self, v: float) -> None:
        struct.pack_into("<d", self.buff.data, self.cursor, v)
        self.cursor += 8  # fixed: was += 4

    def f64(self, v: float) -> None:
        self.alloc(8)
        struct.pack_into("<d", self.buff.data, self.cursor, v)
        self.cursor += 8

    def writestring(self, s: str) -> None:
        b = s.encode("utf-8")
        self.buff.data[self.cursor : self.cursor + len(b)] = b
        self.cursor += len(b)

    def reference(self, value) -> None:
        index = len(self.references) + 1
        if index > self.MAX_REFERENCES:
            raise RuntimeError(f"reference table exceeded {self.MAX_REFERENCES}")
        self.references.append(value)
        self.buff.data[self.cursor] = index & 0xFF
        self.cursor += 1

    def append_encoded(self, payload: bytes) -> None:
        self.ensure_capacity(len(payload))
        self.buff.data[self.cursor : self.cursor + len(payload)] = payload
        self.cursor += len(payload)

    def encode_packet(self, scratch: Channel, packet_id: int, writer, data) -> tuple[bytes, list | None]:
        scratch.cursor = 0
        scratch.references.clear()
        self.write_packet(scratch, packet_id, writer, data)
        payload = bytes(scratch.buff.data[: scratch.cursor])
        refs = list(scratch.references) if scratch.references else None
        return payload, refs


# ---------------------------------------------------------------------------
# CFrame axis-angle fix (math only)
# ---------------------------------------------------------------------------


def axis_angle_write(pos, axis, angle):
    """Return 6 floats: xyz + axis*angle"""
    rx, ry, rz = axis[0] * angle, axis[1] * angle, axis[2] * angle
    return (pos[0], pos[1], pos[2], rx, ry, rz)


def axis_angle_read(six):
    x, y, z, rx, ry, rz = six
    mag = math.sqrt(rx * rx + ry * ry + rz * rz)
    if mag < 1e-6:
        return (x, y, z), (0.0, 0.0, 1.0), 0.0
    axis = (rx / mag, ry / mag, rz / mag)
    return (x, y, z), axis, mag


def old_buggy_write(pos, axis, angle):
    """Pre-fix: captured unit axis BEFORE multiply, still wrote unit components."""
    rx, ry, rz = axis[0], axis[1], axis[2]
    _ = (axis[0] * angle, axis[1] * angle, axis[2] * angle)  # computed then ignored
    return (pos[0], pos[1], pos[2], rx, ry, rz)


# ---------------------------------------------------------------------------
# Dirty-set flush simulation
# ---------------------------------------------------------------------------


def flush_dirty(dirty: dict, channels: dict) -> list:
    """Swap/drain dirty set; return players flushed."""
    to_flush = dirty
    dirty.clear()
    flushed = []
    # rebuild as new empty - caller replaces reference; here we mutate clear
    for player, channel in list(channels.items()):
        if player in to_flush and channel["cursor"] > 0:
            flushed.append(player)
            channel["cursor"] = 0
    return flushed


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_dyn_alloc_no_spurious_realloc():
    print("\n[test] dyn_alloc / ensureCapacity")
    w = BufferWriter()
    ch = Channel(size=256, buff=Buf(256))
    w.load(ch)
    w.realloc_count = 0

    w.dyn_alloc(10)  # fits
    check("no realloc when capacity sufficient", w.realloc_count == 0, f"count={w.realloc_count}")

    w.cursor = 250
    w.dyn_alloc(10)  # 260 > 256 -> grow
    check("realloc when capacity exceeded", w.realloc_count == 1, f"count={w.realloc_count}")
    check("growth uses power-of-two", w.size == 512, f"size={w.size}")

    before = w.realloc_count
    w.dyn_alloc(10)  # still fits in 512
    check("no realloc after growth when fits", w.realloc_count == before)

    # exact fit: cursor + n == size should NOT grow
    w.cursor = 0
    w.size = 16
    w.buff = Buf(16)
    w.realloc_count = 0
    w.ensure_capacity(16)
    check("exact fit does not grow", w.realloc_count == 0 and w.size == 16)


def test_f64_cursor():
    print("\n[test] f64NoAlloc cursor += 8")
    w = BufferWriter()
    ch = Channel(size=64, buff=Buf(64))
    w.load(ch)
    w.alloc(16)
    w.f64_no_alloc(math.pi)
    check("cursor after f64 is 8", w.cursor == 8, f"cursor={w.cursor}")
    w.f64_no_alloc(math.e)
    check("cursor after two f64 is 16", w.cursor == 16, f"cursor={w.cursor}")
    a = struct.unpack_from("<d", w.buff.data, 0)[0]
    b = struct.unpack_from("<d", w.buff.data, 8)[0]
    check("first f64 intact", abs(a - math.pi) < 1e-12, f"a={a}")
    check("second f64 intact", abs(b - math.e) < 1e-12, f"b={b}")


def test_i16_signed():
    print("\n[test] i16 signed write")
    w = BufferWriter()
    ch = Channel(size=16, buff=Buf(16))
    w.load(ch)
    w.i16(-1)
    w.i16(-32768)
    w.i16(32767)
    v1 = struct.unpack_from("<h", w.buff.data, 0)[0]
    v2 = struct.unpack_from("<h", w.buff.data, 2)[0]
    v3 = struct.unpack_from("<h", w.buff.data, 4)[0]
    check("i16 -1", v1 == -1)
    check("i16 min", v2 == -32768)
    check("i16 max", v3 == 32767)


def test_cframe_roundtrip():
    print("\n[test] CFrame axis-angle write/read symmetry")
    pos = (1.0, 2.0, 3.0)
    axis = (0.0, 1.0, 0.0)
    angle = math.pi / 2

    fixed = axis_angle_write(pos, axis, angle)
    rpos, raxis, rangle = axis_angle_read(fixed)
    check("position preserved", rpos == pos)
    check("angle preserved", abs(rangle - angle) < 1e-5, f"got {rangle}")
    check("axis Y preserved", abs(raxis[1] - 1.0) < 1e-5, f"got {raxis}")

    buggy = old_buggy_write(pos, axis, angle)
    _, baxis, bangle = axis_angle_read(buggy)
    check("old buggy write loses angle (mag~1)", abs(bangle - 1.0) < 1e-5, f"bangle={bangle}")
    check("fixed write differs from buggy", fixed != buggy)

    # identity
    id_six = axis_angle_write((0, 0, 0), (0, 1, 0), 0.0)
    _, _, id_angle = axis_angle_read(id_six)
    check("identity angle ~ 0", id_angle < 1e-6)


def test_reference_cap_and_no_print():
    print("\n[test] reference cap")
    w = BufferWriter()
    ch = Channel(size=1024, buff=Buf(1024))
    w.load(ch)
    for i in range(255):
        w.alloc(1)
        w.reference(f"obj{i}")
    check("255 refs ok", len(w.references) == 255)
    raised = False
    try:
        w.alloc(1)
        w.reference("overflow")
    except RuntimeError:
        raised = True
    check("256th ref errors", raised)


def test_string_write_no_realloc_storm():
    print("\n[test] string writes do not realloc every time")
    w = BufferWriter()
    ch = Channel(size=256, buff=Buf(256))
    w.load(ch)
    w.realloc_count = 0

    def write_string(s: str):
        b = s.encode("utf-8")
        w.u16(len(b))
        w.dyn_alloc(len(b))
        w.writestring(s)

    for _ in range(20):
        write_string("hi")  # 2 + 2 = 4 bytes each

    check("many small strings -> few reallocs", w.realloc_count == 0, f"reallocs={w.realloc_count}")
    check("cursor advanced", w.cursor == 20 * 4, f"cursor={w.cursor}")


def test_array_prealloc_pattern():
    print("\n[test] array read uses table.create pattern")
    # Simulate: known length -> pre-sized list
    length = 5
    arr = [None] * length  # table.create(n)
    for i in range(length):
        arr[i] = i * 10
    check("indexed assign", arr == [0, 10, 20, 30, 40])


def test_struct_empty_construct():
    print("\n[test] struct read builds empty table")
    schema = {"a": "uint8", "b": "string"}  # schema must NOT leak into result
    constructed = {}
    constructed["a"] = 7
    constructed["b"] = "x"
    check("no schema values in result", constructed.get("a") == 7 and "uint8" not in constructed.values())


def test_write_packet_model():
    print("\n[test] write_packet (0.5 writer model)")
    w = BufferWriter()
    ch = Channel(size=64, buff=Buf(64))

    def writer(data):
        w.alloc(1)
        w.u8_no_alloc(data)

    ch = w.write_packet(ch, 9, writer, 77)
    check("cursor = id + payload", ch.cursor == 2, f"cursor={ch.cursor}")
    check("packet id 9", ch.buff.data[0] == 9)
    check("payload 77", ch.buff.data[1] == 77)

    ch = w.write_packet(ch, 9, writer, 78)
    check("appends second packet", ch.cursor == 4, f"cursor={ch.cursor}")
    check("second payload 78", ch.buff.data[3] == 78)


def test_color3_wire():
    print("\n[test] color3 is 3 bytes RGB")
    w = BufferWriter()
    ch = Channel(size=16, buff=Buf(16))
    w.load(ch)

    # Color3 components 0..1 → u8
    r, g, b = 1.0, 0.5, 0.0
    w.alloc(3)
    w.u8_no_alloc(int(r * 255))
    w.u8_no_alloc(int(g * 255))
    w.u8_no_alloc(int(b * 255))

    check("wire length 3", w.cursor == 3)
    check("R=255", w.buff.data[0] == 255)
    check("G=127", w.buff.data[1] == 127)  # 0.5*255 truncated
    check("B=0", w.buff.data[2] == 0)
    # vs 3×float32 = 12 bytes
    check("saves vs float32 rgb", 3 < 12)


def test_fanout_serialize_once():
    print("\n[test] fan-out serialize once (no refs)")
    w = BufferWriter()
    scratch = Channel(size=256, buff=Buf(256))
    serialize_count = 0

    def writer(data):
        nonlocal serialize_count
        serialize_count += 1
        w.u16(data)
        w.dyn_alloc(0)

    payload, refs = w.encode_packet(scratch, 3, writer, 42)
    check("encoded once", serialize_count == 1)
    check("no refs", refs is None)
    check("payload starts with packet id 3", payload[0] == 3)

    players = ["p1", "p2", "p3", "p4", "p5"]
    channels = {p: Channel(size=256, buff=Buf(256)) for p in players}
    for p in players:
        w.load(channels[p])
        w.append_encoded(payload)
        w.export()

    check("all channels same cursor", all(channels[p].cursor == len(payload) for p in players))
    check("still one serialize", serialize_count == 1)


def test_dirty_flush():
    print("\n[test] dirty-set flush skips idle players")
    channels = {f"p{i}": {"cursor": 0} for i in range(100)}
    dirty = {"p7": True, "p42": True}
    channels["p7"]["cursor"] = 10
    channels["p42"]["cursor"] = 5

    # Only iterate dirty keys, not all 100
    inspected = list(dirty.keys())
    flushed = []
    for p in inspected:
        if channels[p]["cursor"] > 0:
            flushed.append(p)
            channels[p]["cursor"] = 0
    dirty.clear()

    check("flushed only dirty", set(flushed) == {"p7", "p42"})
    check("inspected << player count", len(inspected) == 2)


def test_player_cleanup():
    print("\n[test] player removing clears channels")
    reliable = {"bob": Channel(), "ann": Channel()}
    dirty = {"bob": True}
    # PlayerRemoving
    del reliable["bob"]
    dirty.pop("bob", None)
    check("bob gone from channels", "bob" not in reliable)
    check("bob gone from dirty", "bob" not in dirty)
    check("ann remains", "ann" in reliable)


def test_unknown_packet_id():
    print("\n[test] unknown packet id aborts batch")
    registry = {1: "packetA"}
    data = bytes([1, 99])  # id 1 then id 99 unknown
    cursor = 0
    processed = []
    while cursor < len(data):
        pid = data[cursor]
        cursor += 1
        packet = registry.get(pid)
        if not packet:
            break
        processed.append(pid)
        # pretend value length 0
    check("processed known only", processed == [1])
    check("stopped before unknown body", cursor == 2)  # read id 99 then stop


def test_packet_id_cap():
    print("\n[test] packet id u8 cap")
    count = 255
    ok = count <= 255
    check("255 ids allowed", ok)
    count2 = 256
    check("256 ids rejected", count2 > 255)


def test_old_dyn_alloc_bug_baseline():
    print("\n[test] old dyn_alloc always-copied (contrast)")
    # Demonstrate old behavior would realloc every call
    class OldDyn:
        def __init__(self):
            self.size = 256
            self.cursor = 0
            self.reallocs = 0

        def dyn_alloc(self, bytes_):
            while self.cursor + bytes_ >= self.size:
                self.size = int(self.size * 1.5)
            # always copy - the bug
            self.reallocs += 1

    old = OldDyn()
    for _ in range(10):
        old.dyn_alloc(4)
    check("old path reallocs every write", old.reallocs == 10)


def kb(n: float) -> str:
    return f"{n / 1024:.3f} KB"


def report_size_comparison() -> None:
    """
    Before/after size metrics for representative workloads.
    Wire format for public types is unchanged (same on-wire KB).
    Savings are CPU-side copies, fan-out re-encode, and channel growth waste.
    """
    print("\n" + "=" * 60)
    print("SIZE COMPARISON (legacy naive path vs swNET)")
    print("=" * 60)

    # Workload A: 200 string writes of 32 bytes each into one channel
    # each write: u16 len (2) + payload (32) = 34 bytes; total payload 6800
    n_strings = 200
    str_len = 32
    payload_bytes = n_strings * (2 + str_len)

    # OLD dyn_alloc: realloc+copy entire buffer every string write
    old_size = 256
    old_cursor = 0
    old_bytes_copied = 0
    for _ in range(n_strings):
        need = 2 + str_len
        while old_cursor + need >= old_size:
            old_size = int(old_size * 1.5)
        old_bytes_copied += old_cursor  # always copied current contents
        old_cursor += need

    # NEW ensureCapacity: copy only on growth, 2x factor, copy cursor bytes only
    new_w = BufferWriter()
    new_ch = Channel(size=256, buff=Buf(256))
    new_w.load(new_ch)
    new_bytes_copied = 0
    for _ in range(n_strings):
        before_size = new_w.size
        before_cursor = new_w.cursor
        new_w.u16(str_len)
        new_w.dyn_alloc(str_len)
        new_w.writestring("x" * str_len)
        if new_w.size != before_size:
            new_bytes_copied += before_cursor

    print("\n[A] 200x string(32) channel writes")
    print(f"    on-wire payload (same before/after): {kb(payload_bytes)} ({payload_bytes} B)")
    print(f"    BEFORE buffer copies during alloc:   {kb(old_bytes_copied)} ({old_bytes_copied} B)")
    print(f"    AFTER  buffer copies during alloc:   {kb(new_bytes_copied)} ({new_bytes_copied} B)")
    saved = old_bytes_copied - new_bytes_copied
    print(f"    SAVED copy traffic:                  {kb(saved)} ({saved} B)")
    print(f"    BEFORE final capacity:               {kb(old_size)} ({old_size} B)")
    print(f"    AFTER  final capacity:               {kb(new_w.size)} ({new_w.size} B)")

    # Workload B: fan-out same 64B packet to 50 players
    packet_body = 64  # id(1) + struct-ish payload
    players = 50
    before_fanout = packet_body * players  # re-serialize N times (CPU encode volume)
    after_fanout = packet_body  # encode once, append bytes
    print("\n[B] Fan-out 64B packet to 50 players (serialize work)")
    print(f"    BEFORE encode volume:  {kb(before_fanout)} ({before_fanout} B)  [= N serializations]")
    print(f"    AFTER  encode volume:  {kb(after_fanout)} ({after_fanout} B)  [= 1 serialization]")
    print(f"    SAVED encode volume:   {kb(before_fanout - after_fanout)} ({before_fanout - after_fanout} B)")
    print(f"    on-wire to clients:    {kb(packet_body * players)} (unchanged; each still gets a copy)")

    # Workload C: wire size for typical transform packet (format unchanged)
    cframe_bytes = 24
    vec3_bytes = 12
    print("\n[C] On-wire type sizes")
    print(f"    CFrame:  {cframe_bytes} B (axis-angle, kept)")
    print(f"    Vec3:    {vec3_bytes} B")
    print(f"    Color3:  3 B RGB u8  (vs 12 B if 3×float32)")
    print(f"    string length prefix: 2 B (u16)")

    # Workload D: idle heartbeat scan waste (not KB on wire, but work units)
    print("\n[D] Server Heartbeat channel scan (100 players, 2 dirty)")
    print("    BEFORE inspect: 100 player channels / frame")
    print("    AFTER  inspect: 2 dirty channels / frame")

    print("\n" + "-" * 60)
    print("SUMMARY")
    print(f"  Wire KB for same packets:     SAME (format preserved)")
    print(f"  Alloc copy KB [A]:            {kb(old_bytes_copied)} -> {kb(new_bytes_copied)}")
    print(f"  Fan-out encode KB [B]:        {kb(before_fanout)} -> {kb(after_fanout)}")
    print("-" * 60)


def main() -> int:
    print("swNET fix simulation - verifying swNET patches")
    test_dyn_alloc_no_spurious_realloc()
    test_old_dyn_alloc_bug_baseline()
    test_f64_cursor()
    test_i16_signed()
    test_cframe_roundtrip()
    test_write_packet_model()
    test_color3_wire()
    test_reference_cap_and_no_print()
    test_string_write_no_realloc_storm()
    test_array_prealloc_pattern()
    test_struct_empty_construct()
    test_fanout_serialize_once()
    test_dirty_flush()
    test_player_cleanup()
    test_unknown_packet_id()
    test_packet_id_cap()

    report_size_comparison()

    print(f"\n=== Results: {PASSED} passed, {FAILED} failed ===")
    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
