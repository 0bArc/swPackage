# Choosing codecs

1. Prefer fixed ints over floats for ids and enums.
2. Prefer `uint8`/`uint16` when ranges fit.
3. Use `color3` (3B) instead of three float32s (12B).
4. Use `cframe` only when you need rotation; else `vec3`.
5. Avoid `inst` and `unknown` on anything high rate; they consume reference slots (max 255 refs per batch) and prevent shared fanout encode.
6. `string` is fine for chat; bad for per-frame labels (send ids instead).
7. `optional` beats sentinel values when absence is common.
