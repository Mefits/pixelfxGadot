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

static func scale_color(c: int,k: float) -> int:
    return rgb(minf(255,(c&255)*k),minf(255,((c>>8)&255)*k),minf(255,((c>>16)&255)*k))

const PALETTES={
  "fire": [
    "#1f0b10",
    "#4a1118",
    "#8c1d1c",
    "#cc3a1a",
    "#f2701f",
    "#ffae35",
    "#ffe27a",
    "#fff8d6"
  ],
  "ember": [
    "#1a0a0e",
    "#3d1012",
    "#701a14",
    "#a8301a",
    "#e0561e",
    "#ff8a2a",
    "#ffc46a"
  ],
  "lava": [
    "#14060a",
    "#380a10",
    "#6e1210",
    "#ac2410",
    "#e8501a",
    "#ff8c2a",
    "#ffd25a"
  ],
  "smoke": [
    "#0e0c12",
    "#1d1a22",
    "#2e2a35",
    "#433e4b",
    "#5c5664",
    "#7b7484",
    "#a39cab"
  ],
  "dust": [
    "#1c1610",
    "#33281c",
    "#4f3f2c",
    "#6e5a40",
    "#927a58",
    "#b89f78",
    "#dcc8a2"
  ],
  "ice": [
    "#0c1430",
    "#162c5c",
    "#1f4f94",
    "#2f7fcc",
    "#58b4ec",
    "#9bdcff",
    "#d8f4ff",
    "#ffffff"
  ],
  "water": [
    "#081830",
    "#0e2e5a",
    "#14508c",
    "#1c76bc",
    "#36a2e0",
    "#78ccf4",
    "#c4ecff",
    "#ffffff"
  ],
  "electric": [
    "#0a0f2e",
    "#172a78",
    "#2550d0",
    "#3f8cff",
    "#7cc8ff",
    "#c8f0ff",
    "#ffffff"
  ],
  "volt": [
    "#24160a",
    "#5e3a0c",
    "#a8680f",
    "#e8a218",
    "#ffd23c",
    "#fff08a",
    "#ffffff"
  ],
  "poison": [
    "#0d1a0c",
    "#173a14",
    "#265e18",
    "#3f8a1e",
    "#6cb82a",
    "#a8e04a",
    "#e0ff8a"
  ],
  "holy": [
    "#2a1c08",
    "#5a3e10",
    "#9a6c18",
    "#d8a428",
    "#ffd84a",
    "#fff09a",
    "#fffbe6",
    "#ffffff"
  ],
  "heal": [
    "#08201a",
    "#0f3f2c",
    "#17663e",
    "#24924e",
    "#3ec466",
    "#7ee88a",
    "#c8ffc4",
    "#ffffff"
  ],
  "arcane": [
    "#140a26",
    "#2b1252",
    "#481c88",
    "#6b2cc0",
    "#9a48ec",
    "#c684ff",
    "#ecc8ff",
    "#ffffff"
  ],
  "shadow": [
    "#050308",
    "#0f0a18",
    "#1c1230",
    "#2c1a4a",
    "#432468",
    "#5e3290",
    "#8048b8",
    "#a970e0"
  ],
  "blood": [
    "#14040a",
    "#3a0a14",
    "#6a101c",
    "#a01824",
    "#d42a30",
    "#ff5a50",
    "#ff9a8a"
  ],
  "earth": [
    "#140e0a",
    "#2a1e14",
    "#47321e",
    "#69492a",
    "#8e6638",
    "#b88a52",
    "#dcb47c"
  ],
  "stone": [
    "#0e0e12",
    "#1c1c24",
    "#2c2c38",
    "#42424f",
    "#5c5c6b",
    "#7d7d8c",
    "#a4a4b2",
    "#d0d0da"
  ],
  "gold": [
    "#1e1206",
    "#4a2c08",
    "#86520c",
    "#c48412",
    "#f0b424",
    "#ffe066",
    "#fff6c4",
    "#ffffff"
  ],
  "leaf": [
    "#0c1a0e",
    "#163418",
    "#225224",
    "#357530",
    "#4f9a3a",
    "#7cc048",
    "#b4e070",
    "#e4ffb0"
  ],
  "wood": [
    "#160c06",
    "#2e1a0c",
    "#4a2c14",
    "#6a421e",
    "#8e5c2c",
    "#b47c40",
    "#d8a464"
  ],
  "metal": [
    "#0c0e14",
    "#1c2230",
    "#2e3648",
    "#4a5468",
    "#6e7a90",
    "#9aa6ba",
    "#d0d8e6",
    "#ffffff"
  ],
  "bone": [
    "#1a1814",
    "#3a352c",
    "#5e5648",
    "#8a806c",
    "#b8ad96",
    "#e4dcc8",
    "#fffaf0"
  ],
  "neon": [
    "#1a0516",
    "#3d0a33",
    "#701560",
    "#b0228f",
    "#f53cd1",
    "#ff86e6",
    "#ffd2f6",
    "#ffffff"
  ],
  "cyber": [
    "#041418",
    "#08303a",
    "#0c5260",
    "#108088",
    "#18b4b0",
    "#4ce8d8",
    "#b4fff0",
    "#ffffff"
  ],
  "matrix": [
    "#020a04",
    "#05200c",
    "#0a3c16",
    "#106624",
    "#1a9a34",
    "#3cd650",
    "#a4ffa8",
    "#e8ffe8"
  ],
  "candy": [
    "#ff4a5a",
    "#ff9a2a",
    "#ffe03c",
    "#5ad84a",
    "#3cc8ff",
    "#7a6cff",
    "#f53cd1"
  ],
  "night": [
    "#07060d",
    "#0c0a18",
    "#131026",
    "#1b1734",
    "#241f44",
    "#2f2956"
  ]
}

static func to_hex(c: int) -> String:
    return "#%02x%02x%02x"%[c&255,(c>>8)&255,(c>>16)&255]

static func luma(c: int) -> float:
    return (0.299*(c&255)+0.587*((c>>8)&255)+0.114*((c>>16)&255))/255.0

static func blend_ramp(r: Array,t: float) -> int:
    if r.size()==1:
        return int(r[0])
    var x: float=clampf(t,0,1)*(r.size()-1)
    var i: int=mini(r.size()-2,int(floor(x)))
    return mix(r[i],r[i+1],x-i)
