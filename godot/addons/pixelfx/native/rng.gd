extends RefCounted
## Direct port of PixelFX src/core/math.js hash() and Rng (mulberry32).
## Original MIT: Patch, Hugo Duprez, 2026. See LICENSE-PixelFX.txt.
const MASK: int = 0xffffffff
var state: int = 1

func _init(seed_value: int = 1) -> void:
    state = seed_value & MASK
    if state == 0:
        state = 1

static func imul32(a: int, b: int) -> int:
    # Only low 32 bits are required. Split words to avoid signed 64-bit overflow.
    var lo: int = (a & 0xffff) * (b & 0xffff)
    var hi: int = ((a >> 16) & 0xffff) * (b & 0xffff) + (a & 0xffff) * ((b >> 16) & 0xffff)
    return (lo + ((hi & 0xffff) << 16)) & MASK

static func hash32(ns: Array) -> int:
    var h: int = 0x9e3779b9
    for n in ns:
        h = imul32(h ^ (int(n) & MASK), 0x85ebca6b)
        h ^= h >> 13
        h = imul32(h, 0xc2b2ae35)
        h ^= h >> 16
    return h & MASK

func next_u32() -> int:
    state = (state + 0x6d2b79f5) & MASK
    var t: int = state
    t = imul32(t ^ (t >> 15), t | 1)
    t = (t ^ ((t + imul32(t ^ (t >> 7), t | 61)) & MASK)) & MASK
    return (t ^ (t >> 14)) & MASK

func next() -> float:
    return float(next_u32()) / 4294967296.0

func between(a: float, b: float) -> float:
    return a + (b - a) * next()

func chance(p: float) -> bool:
    return next() < p

func sign() -> int:
    return -1 if next() < 0.5 else 1
