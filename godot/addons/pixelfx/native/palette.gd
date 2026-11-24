extends RefCounted
## Port of integer color/ramp operations in src/core/color.js.
## Original MIT: Patch, Hugo Duprez, 2026.
static func rgb(r: float, g: float, b: float) -> int:
    return 0xff000000 | ((int(b) & 255) << 16) | ((int(g) & 255) << 8) | (int(r) & 255)

static func from_hex(value: String) -> int:
    var s: String = value.trim_prefix("#")
    if s.length() == 3:
        s = s[0].repeat(2) + s[1].repeat(2) + s[2].repeat(2)
    var v: int = s.substr(0,6).hex_to_int()
    return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255)

static func fit(ramp: Array, n: int) -> Array[int]:
    var out: Array[int] = []
    if ramp.is_empty() or n < 1:
        return out
    for i in range(n):
        var k: int = int(floor(float(i * (ramp.size() - 1)) / maxi(1,n - 1) + 0.5))
        var v: Variant = ramp[k]
        out.append(from_hex(v) if v is String else int(v))
    return out

static func at(ramp: Array, t: float) -> int:
    return int(ramp[clampi(int(floor(t * ramp.size())),0,ramp.size() - 1)])

static func mix(a: int, b: int, t: float) -> int:
    var k: float = clampf(t,0.0,1.0)
    return rgb(lerpf(a & 255,b & 255,k),lerpf((a >> 8) & 255,(b >> 8) & 255,k),lerpf((a >> 16) & 255,(b >> 16) & 255,k))
