extends Node2D
## Environment Lab v0.03. Original authored composition using the native PixelFX Painter.
## PixelFX primitives and deterministic RNG: MIT, Patch/Hugo Duprez; see toolkit notices.
const COMBAT_LIGHTING = preload("res://lab/environment/combat_lighting.gd")
var combat_lighting = COMBAT_LIGHTING.new()
const P = preload("res://addons/pixelfx/native/painter.gd")
const PAL = preload("res://addons/pixelfx/native/palette.gd")
const M = preload("res://addons/pixelfx/native/math.gd")
const STAR_SHADER = preload("res://lab/environment/starfield.gdshader")
const PERIOD: float = 12.0
const BASE = Vector2(640, 360)
@export var internal_width: int = 640
@export var seed: int = 71
@export var animate: bool = true
var phase: float = 0.0
var generation_us: int = 0
var star_material: ShaderMaterial
var moon_light: Sprite2D
var cloud_layers: Array[Sprite2D] = []
var shrubs: Array[Sprite2D] = []
var leaves: Array[Sprite2D] = []
var leaf_anchors: Array[Vector2] = []
const SHRUB_SHADER = preload("res://lab/environment/shrub_wind.gdshader")
var layers: Array[Sprite2D] = []
var factor: float = 1.0
var raster_width: int
var raster_height: int
var world: Node2D

func _ready() -> void:
    var started := Time.get_ticks_usec()
    raster_width = 960 if internal_width >= 960 else 640
    raster_height = int(raster_width * 9.0 / 16.0)
    factor = raster_width / BASE.x
    world = Node2D.new()
    add_child(world)
    _build()
    generation_us = Time.get_ticks_usec() - started
    get_viewport().size_changed.connect(_fit)
    _fit()
    set_time(0.0)

func _fit() -> void:
    var v := get_viewport_rect().size
    var k := minf(v.x / BASE.x, v.y / BASE.y)
    world.scale = Vector2.ONE * k
    world.position = (v - BASE * k) * 0.5

func _process(dt: float) -> void:
    if animate:
        set_time(phase + dt)
    combat_lighting.tick(dt)

# Positions/radii are in the arena's 640x360 coordinate space, not viewport pixels.
func emit_combat_light(at: Vector2, radius: float, tint: Color, energy: float, lifetime: float) -> bool:
    return combat_lighting.emit_light(at,radius,tint,energy,lifetime)

# Replace the live effect source snapshot each visual frame. The caller owns its simulation.
# Each entry: {"lights": PixelFX Lights, "origin": Vector2, "scale": float, "reach": float}.
func publish_combat_lights(sources: Array, sustained: Array = []) -> void:
    combat_lighting.publish(sources,sustained)

func set_time(seconds: float) -> void:
    phase = fposmod(seconds, PERIOD)
    var a := TAU * phase / PERIOD
    star_material.set_shader_parameter("cycle_phase", phase / PERIOD)
    moon_light.modulate.a = 0.72 + 0.12 * cos(a)
    # Fixed authored silhouettes, gently drifting by different amounts. No regeneration.
    cloud_layers[0].position = Vector2(0.65 * sin(a), 0.12 * sin(a + 0.5))
    cloud_layers[1].position = Vector2(0.9 * sin(a + 0.6), 0.15 * cos(a))
    cloud_layers[2].position = Vector2(1.25 * sin(a + 1.1), 0.18 * sin(a + 0.2))
    cloud_layers[3].position = Vector2(1.55 * sin(a + 1.7), 0.15 * cos(a + 0.4))
    for i in range(shrubs.size()):
        var mat := shrubs[i].material as ShaderMaterial
        mat.set_shader_parameter("wind", 0.52 * sin(2.0*a + i*0.8) + 0.28 * sin(3.0*a + i*1.3))
    for i in range(leaves.size()):
        # Each leaf travels once per cycle; zero alpha and zero alpha derivative at the reset.
        var u := fposmod(phase/PERIOD + i*0.173, 1.0)
        var leaf := leaves[i]
        leaf.position = leaf_anchors[i] + Vector2(50.0*u, -8.0*sin(PI*u) + 2.0*sin(TAU*u + i))
        leaf.rotation = 0.55*sin(TAU*u + i) + 0.18*sin(2.0*TAU*u)
        leaf.modulate.a = 0.58 * pow(sin(PI*u), 2.0)

func _p():
    return P.new(raster_width, raster_height)

func _c(hex: String) -> int:
    return PAL.from_hex(hex)

func _r(i: int, j: int) -> float:
    return M.rand_hash([seed, i, j])

func _poly(p, pts: Array, color: String) -> void:
    # Same even-odd pixel-center fill as PixelFX Painter.poly, but scanline intersections
    # are calculated once per row. Use Painter.line for spans, not a per-pixel polygon test.
    var q: Array[Vector2] = []
    var low: float = INF
    var high: float = -INF
    for pt in pts:
        var v := Vector2(float(pt[0]),float(pt[1])) * factor
        q.append(v)
        low = minf(low,v.y)
        high = maxf(high,v.y)
    if q.size()<3:
        return
    var ink := _c(color)
    for y in range(maxi(0,int(ceil(low-0.5))),mini(raster_height,int(ceil(high-0.5)))):
        var py: float = y+0.5
        var xs: Array[float] = []
        for i in range(q.size()):
            var a: Vector2 = q[i]
            var b: Vector2 = q[(i+1)%q.size()]
            if (a.y>py)!=(b.y>py):
                xs.append(a.x + (py-a.y)*(b.x-a.x)/(b.y-a.y))
        xs.sort()
        for j in range(0,xs.size()-1,2):
            var x0: int = maxi(0,int(ceil(xs[j]-0.5)))
            var x1: int = mini(raster_width-1,int(ceil(xs[j+1]-0.5))-1)
            if x1>=x0:
                p.line(x0,y,x1,y,ink)

func _ellipse(p, x: float, y: float, rx: float, ry: float, color: String) -> void:
    p.ellipse(x * factor, y * factor, rx * factor, ry * factor, _c(color))

func _line(p, x: float, y: float, x2: float, y2: float, color: String) -> void:
    p.line(x * factor, y * factor, x2 * factor, y2 * factor, _c(color))

func _rect(p, x: float, y: float, w: float, h: float, color: String) -> void:
    p.rect(x * factor, y * factor, w * factor, h * factor, _c(color))

func _texture(p, is_light: bool = false) -> ImageTexture:
    return ImageTexture.create_from_image(Image.create_from_data(raster_width, raster_height, false, Image.FORMAT_RGBA8, p.rgba_bytes(is_light)))

func _sprite(p, label_name: String, moving: bool = false, is_light: bool = false) -> Sprite2D:
    var s := Sprite2D.new()
    s.name = label_name
    s.centered = false
    s.scale = Vector2.ONE / factor
    s.texture = _texture(p, is_light)
    s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if moving else CanvasItem.TEXTURE_FILTER_NEAREST
    var mat := CanvasItemMaterial.new()
    mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
    if is_light:
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    s.material = mat
    world.add_child(s)
    layers.append(s)
    return s

func _build() -> void:
    var sky = _p()
    # Opaque full-frame clear, same packed RGBA as Painter.rect.
    sky.color.fill(_c("020306") - 0x100000000)
    # Sweeping night bands, laid out explicitly to preserve the reference's open sky.
    _ribbon(sky, [Vector2(-30, 49), Vector2(170, -31), Vector2(443, -23), Vector2(680, 61)], 16, "0a101a")
    _ribbon(sky, [Vector2(-38, 90), Vector2(145, 11), Vector2(380, 3), Vector2(660, 77)], 12, "080e18")
    _ribbon(sky, [Vector2(12, 77), Vector2(80, 50), Vector2(126, 35), Vector2(132, 53)], 16, "0c1420")
    _ribbon(sky, [Vector2(169, 53), Vector2(232, 25), Vector2(341, 26), Vector2(365, 42)], 9, "0a121d")
    _ribbon(sky, [Vector2(310, 40), Vector2(400, 32), Vector2(465, 47), Vector2(518, 60)], 15, "0a111c")
    _ribbon(sky, [Vector2(535, 72), Vector2(588, 70), Vector2(638, 80), Vector2(686, 100)], 10, "0a111b")
    _sprite(sky, "Sky")
    _stars()
    var distant = _p()
    _bank(distant, [[-32,170,62,45],[31,158,47,35],[90,154,39,40],[145,162,55,35],[202,116,38,42],[264,111,43,53],[313,100,46,48],[366,120,54,42],[426,143,62,37],[500,150,56,48],[570,166,60,41],[640,178,58,35]], "080f1d", 6.0)
    _ribbon(distant, [Vector2(-38,194),Vector2(167,117),Vector2(427,105),Vector2(682,197)], 27, "080e19")
    _ribbon(distant, [Vector2(85,220),Vector2(176,143),Vector2(397,142),Vector2(551,217)], 13, "0a182c")
    cloud_layers.append(_sprite(distant, "DistantAtmosphere", true))
    var moon = _p()
    _ellipse(moon, 316, 125, 15.5, 15.5, "d7efff")
    _ellipse(moon, 315, 123, 13.0, 13.0, "f9fdff")
    moon.glow(316 * factor, 125 * factor, 39 * factor, _c("2d85db"), 0.34)
    moon.glow(316 * factor, 125 * factor, 21 * factor, _c("a3e6ff"), 0.20)
    moon_light = _sprite(moon, "MoonHalo", false, true)
    _sprite(moon, "Moon")
    _clouds()
    _terrain()
    _foliage()

func _ribbon(p, control: Array, width: float, color: String) -> void:
    var upper: Array = []
    var lower: Array = []
    for i in range(41):
        var u: float = float(i) / 40.0
        var a: Vector2 = control[0]
        var b: Vector2 = control[1]
        var c: Vector2 = control[2]
        var d: Vector2 = control[3]
        var v := a.bezier_interpolate(b,c,d,u)
        var tangent := 3.0 * (1-u)*(1-u)*(b-a) + 6.0*(1-u)*u*(c-b) + 3.0*u*u*(d-c)
        var n := Vector2(-tangent.y,tangent.x).normalized()
        var w := width * pow(maxf(0.0,sin(PI*u)),0.65)
        var top := v - n * w
        var bot := v + n * w
        upper.append([top.x,top.y])
        lower.push_front([bot.x,bot.y])
    upper.append_array(lower)
    _poly(p,upper,color)

func _bank(p, lobes: Array, color: String, belly: float) -> void:
    # Upper envelope of overlapping ellipses, inspired by weather/clouds.js.
    # Authored puffs remain connected by a curved lower silhouette.
    var first: float = 1000.0
    var last: float = -1000.0
    for l in lobes:
        first = minf(first, float(l[0])-float(l[2]))
        last = maxf(last, float(l[0])+float(l[2]))
    var upper: Array = []
    var lower: Array = []
    for xi in range(int(floor(first)), int(ceil(last))+1, 2):
        var x: float = float(xi)
        var top: float = 1000.0
        var bot: float = -1000.0
        for l in lobes:
            var dx: float = (x-float(l[0]))/float(l[2])
            if absf(dx) >= 1.0:
                continue
            var dy: float = float(l[3]) * sqrt(maxf(0.0,1.0-dx*dx))
            top = minf(top, float(l[1])-dy)
            bot = maxf(bot, float(l[1])+dy*0.35+belly)
        if bot > top:
            upper.append([x,top])
            lower.push_front([x,bot])
    if upper.size()>2:
        upper.append_array(lower)
        _poly(p,upper,color)

func _clouds() -> void:
    var back = _p()
    _ribbon(back, [Vector2(115,213),Vector2(205,140),Vector2(382,135),Vector2(500,214)], 14, "0a2445")
    _bank(back, [[172,173,29,17],[199,151,30,29],[230,137,27,24],[260,145,37,19],[307,151,32,16],[350,139,37,16],[381,144,37,26],[418,158,30,22],[453,176,22,12]], "103c68", 2.0)
    _bank(back, [[176,170,20,14],[198,151,25,23],[227,137,23,20],[250,143,22,15],[340,140,28,10],[367,135,23,13],[400,151,27,22],[430,165,20,17]], "185c92", 0.0)
    cloud_layers.append(_sprite(back, "CloudBack", true))
    var mass = _p()
    _bank(mass, [[159,182,15,10],[176,172,21,17],[200,166,20,24],[220,147,22,18],[252,140,29,24],[270,157,23,19],[292,169,32,19]], "0b467a", 4.0)
    _bank(mass, [[155,182,12,7],[177,168,18,14],[200,158,18,17],[221,145,22,13],[248,137,24,21],[270,155,16,12]], "2998c6", 1.0)
    _bank(mass, [[166,176,13,8],[194,161,16,13],[215,150,20,10],[245,134,22,17],[259,142,13,8]], "39add6", 0.0)
    _bank(mass, [[247,157,20,15],[272,163,19,12],[288,176,20,7]], "1c78ad", 0.0)
    _bank(mass, [[322,162,24,15],[345,144,28,20],[371,138,26,20],[396,149,27,19],[421,160,29,18],[452,180,20,12],[468,192,10,9]], "10639e", 3.0)
    _bank(mass, [[327,152,23,13],[350,137,23,11],[373,134,24,15],[391,145,24,15],[418,160,17,12]], "218ac0", 0.0)
    _bank(mass, [[339,159,18,14],[366,158,23,20],[391,171,25,16],[425,180,30,14],[450,193,20,9]], "0b4278", 1.0)
    # More varied overlapping lobes and restrained moonlit rim, not global brightening.
    _bank(mass, [[190,159,11,9],[208,153,12,11],[225,143,14,10]], "42b0d6", 0.0)
    _bank(mass, [[233,154,14,9],[250,150,15,11],[269,159,13,7]], "2282b5", 0.0)
    _bank(mass, [[354,148,13,11],[374,143,16,11],[393,153,13,8]], "37a4d1", 0.0)
    _bank(mass, [[385,168,14,9],[404,174,18,11],[425,183,15,7]], "145586", 0.0)
    _ribbon(mass, [Vector2(145,193),Vector2(199,173),Vector2(244,170),Vector2(290,173)], 4.7, "299ac9")
    _ribbon(mass, [Vector2(160,203),Vector2(222,172),Vector2(277,170),Vector2(313,169)], 4.0, "0b294c")
    _ribbon(mass, [Vector2(177,207),Vector2(230,182),Vector2(272,180),Vector2(311,174)], 2.7, "1b75a6")
    _ribbon(mass, [Vector2(317,157),Vector2(373,160),Vector2(434,179),Vector2(478,209)], 5.0, "1e7fb7")
    _ribbon(mass, [Vector2(358,174),Vector2(403,173),Vector2(448,195),Vector2(484,214)], 3.0, "0a2849")
    cloud_layers.append(_sprite(mass, "CloudMain", true))
    var front = _p()
    _bank(front, [[273,191,15,9],[287,183,21,11],[308,174,22,17],[329,174,24,14],[350,185,19,9],[363,191,17,6]], "288dbd", 3.0)
    _bank(front, [[276,187,13,6],[300,177,17,10],[319,170,18,14],[339,180,19,9],[354,188,14,6]], "40b1dc", 0.0)
    _ribbon(front, [Vector2(245,208),Vector2(285,186),Vector2(341,182),Vector2(372,193)], 4.8, "3bafd6")
    _ribbon(front, [Vector2(244,215),Vector2(280,193),Vector2(329,193),Vector2(356,195)], 2.4, "1873a7")
    _ribbon(front, [Vector2(202,213),Vector2(238,196),Vector2(271,188),Vector2(299,189)], 2.3, "19598a")
    cloud_layers.append(_sprite(front, "CloudForeground", true))

func _star_mark(p, x: float, y: float, radius: int, core: int, arms: int) -> void:
    var xx := int(round(x*factor))
    var yy := int(round(y*factor))
    var rr := int(round(radius*factor))
    if rr > 0:
        p.line(xx-rr, yy, xx+rr, yy, arms)
        p.line(xx, yy-rr, xx, yy+rr, arms)
    p.px(xx, yy, core)

func _stars() -> void:
    var stars = _p()
    var data = _p()
    # shooting-stars.js sky(): stable positions, integer harmonic counts and seeded phases.
    # A spatial occupancy grid prevents a bright cross from sharing another star's phase.
    var occupied: Array[Vector2] = []
    var count: int = 0
    for i in range(1600):
        if count >= 570:
            break
        var x: float = 3.0 + _r(i,1)*634.0
        var y: float = 2.0 + _r(i,2)*328.0
        var v := Vector2(x,y)
        var too_close := false
        for other in occupied:
            if v.distance_squared_to(other)<20.0:
                too_close = true
                break
        if too_close:
            continue
        occupied.append(v)
        var pick: float = _r(i,3)
        var radius: int = 0 if pick < 0.59 else (1 if pick < 0.89 else 2)
        var bright: float = 0.61 + 0.39*_r(i,4)
        var cool: bool = _r(i,5) < 0.56
        var core: int = PAL.scale_color(_c("d9f6ff" if cool else "f3f5ff"),bright)
        var arms: int = PAL.scale_color(_c("55c6ee" if cool else "9aafc8"),bright*0.88)
        var harmonic: int = 1 + int(_r(i,6)*4.0)
        var packed: int = PAL.rgb(_r(i,7)*255.0, harmonic*51, 75+_r(i,8)*160.0)
        _star_mark(stars,x,y,radius,core,arms)
        _star_mark(data,x,y,radius,packed,packed)
        count += 1
    var sprite := _sprite(stars,"Stars")
    star_material = ShaderMaterial.new()
    star_material.shader = STAR_SHADER
    star_material.set_shader_parameter("phase_map",_texture(data))
    sprite.material = star_material

func _arch(p, cx: float, cy: float, r: float, width: float, begin: float, end: float, n: int) -> void:
    for i in range(n):
        var a: float = lerpf(begin,end,float(i)/n)+0.007
        var b: float = lerpf(begin,end,float(i+1)/n)-0.007
        var pts: Array = []
        for j in range(7):
            var t: float = lerpf(a,b,float(j)/6)
            pts.append([cx+cos(t)*r,cy+sin(t)*r])
        for j in range(6,-1,-1):
            var t: float = lerpf(a,b,float(j)/6)
            pts.append([cx+cos(t)*(r-width),cy+sin(t)*(r-width)])
        _poly(p,pts,["0b203b","0d284b","102c51","0c2444"][i%4])
        _line(p,cx+cos(a)*r,cy+sin(a)*r,cx+cos(a)*(r-width),cy+sin(a)*(r-width),"0a192e")
        for j in range(6):
            var t0: float = lerpf(a,b,float(j)/6)
            var t1: float = lerpf(a,b,float(j+1)/6)
            _line(p,cx+cos(t0)*r,cy+sin(t0)*r,cx+cos(t1)*r,cy+sin(t1)*r,"173e6c")

func _slab(p, x: float, y: float, w: float, h: float, lean: float, i: int) -> void:
    var foot: float = y+h
    var t: float = 6.0+_r(i,20)*8.0
    var ridge: float = w*0.58
    _poly(p,[[x,y],[x+w-t,y-3],[x+w,y+7],[x+w+lean,foot],[x+lean,foot]],"0b1729")
    _poly(p,[[x,y],[x+ridge,y-1],[x+ridge+lean-4,foot],[x+lean,foot]],"102f52")
    _poly(p,[[x+ridge,y-1],[x+w-t,y-3],[x+w,y+7],[x+w+lean,foot],[x+ridge+lean-4,foot]],"0a1c33")
    _poly(p,[[x-3,y],[x+w-t,y-5],[x+w+3,y],[x+w+4,y+5],[x+3,y+8]],"155488")
    _poly(p,[[x+1,y+3],[x+w-5,y+1],[x+w,y+6],[x+8,y+8]],"103e69")
    _poly(p,[[x+4,y+12],[x+ridge-3,y+10],[x+ridge+lean*0.44-6,y+h*0.47],[x+lean*0.44+2,y+h*0.5]],"12395e")
    _line(p,x+ridge,y+10,x+ridge+lean*0.74-4,y+h*0.75,"1a4b76")
    _line(p,x+ridge+lean*0.74-4,y+h*0.75,x+ridge+lean-4,foot-3,"0a213d")
    for j in range(5):
        var yy: float = y+14+_r(i,30+j)*(h-15)
        var xx: float = x+lean*(yy-y)/h+4+_r(i,40+j)*(w*0.38)
        _line(p,xx,yy,xx+5+_r(i,50+j)*8,yy-2,"0a2038")
    for j in range(int(w/4.0)):
        var xx: float = x+j*4+_r(i,j+90)*3
        if _r(i,j+120)>0.28:
            _ellipse(p,xx,y-1-2*_r(i,j+140),2.2,1.1,"206293")

func _terrain() -> void:
    var p = _p()
    _arch(p,79,343,64,19,-PI,-0.33,13)
    _arch(p,574,307,57,22,-2.59,0.38,17)
    _arch(p,578,321,44,16,-2.5,-0.15,12)
    _poly(p,[[0,316],[28,309],[63,310],[101,323],[132,313],[185,317],[228,324],[268,329],[307,325],[335,323],[389,324],[441,310],[490,316],[524,307],[555,301],[596,303],[640,311],[640,334],[0,334]],"080e18")
    # Deliberately asymmetrical hand-placed architecture, not randomized silhouettes.
    _slab(p,115,291,34,42,-6,10)
    _slab(p,150,285,39,48,11,11)
    _slab(p,185,264,53,69,17,12)
    _slab(p,178,293,39,40,11,13)
    _slab(p,132,310,35,23,-5,14)
    _slab(p,221,289,47,44,11,15)
    _slab(p,242,310,35,23,12,16)
    _slab(p,398,284,45,49,-24,20)
    _slab(p,431,280,35,53,-18,21)
    _slab(p,454,264,48,69,-17,22)
    _slab(p,485,290,28,43,8,23)
    _slab(p,510,308,24,25,6,24)
    # Irregular fractured blocks break up the repetitive column silhouettes.
    _poly(p,[[173,303],[189,281],[204,278],[213,299],[206,313],[179,319]],"15395e")
    _poly(p,[[173,303],[189,281],[204,278],[197,286],[182,309]],"23567e")
    _poly(p,[[433,312],[447,293],[466,290],[475,309],[464,321],[438,322]],"123252")
    _poly(p,[[433,312],[447,293],[466,290],[457,297],[440,315]],"1c5078")
    for i in range(45):
        var side: bool = i%2==0
        var x: float = (110+_r(i,201)*166) if side else (390+_r(i,201)*155)
        var y: float = 325.0-_r(i,202)*8.0
        _ellipse(p,x,y,3+_r(i,203)*8,1.5+_r(i,204)*3.2,["0c2541","12395d","15497a"][i%3])
    var ruins := _sprite(p,"Ruins")
    combat_lighting.attach_receiver(ruins,p,false)
    var floor = _p()
    _rect(floor,0,330,640,30,"080e18")
    _poly(floor,[[107,330],[535,330],[514,342],[470,353],[458,360],[192,360],[170,351],[135,348]],"0a2442")
    # Deterministic stone mosaic; bright only at the combat plane.
    for row in range(4):
        for i in range(38):
            var id: int = row*38+i
            var x: float = 110.0+i*11.5+_r(id,211)*3.0+(row%2)*5.0
            var y: float = 334.0+row*8.0+_r(id,212)*1.4
            if x<110+row*11 or x>535-row*13:
                continue
            var w: float = 5.0+_r(id,213)*2.8
            var h: float = 3.0+_r(id,214)*2.6
            var col: String = ["102e4e","123654","164066","0d2947"][int(_r(id,215)*4.0)]
            if row==0:
                col=["16517c","226e95","3386aa","174b71"][id%4]
            _poly(floor,[[x-w,y],[x-1,y-h],[x+w,y-h*0.4],[x+w*0.45,y+h],[x-w*0.5,y+h*0.7]],col)
            if row==0 and _r(id,216)>0.4:
                _line(floor,x-w*0.65,y-1,x-1,y-h,"408eae")
    _rect(floor,0,330,640,1,"32677e")
    _rect(floor,107,330,428,1,"76d8ed")
    var plane := _sprite(floor,"CombatPlane")
    combat_lighting.attach_receiver(plane,floor,true)


# Small textures use the actual PixelFX Painter; no full-screen allocations for vegetation.
func _local_texture(p) -> ImageTexture:
    return ImageTexture.create_from_image(Image.create_from_data(p.width,p.height,false,Image.FORMAT_RGBA8,p.rgba_bytes()))

func _local_sprite(tex: Texture2D, anchor: Vector2, label_name: String, offset_px: Vector2) -> Sprite2D:
    var sp := Sprite2D.new()
    sp.name = label_name
    sp.texture = tex
    sp.centered = false
    sp.offset = offset_px * factor
    sp.scale = Vector2.ONE / factor
    sp.position = anchor
    sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    world.add_child(sp)
    layers.append(sp)
    return sp

func _twig(p, a: Vector2, b: Vector2, c: String) -> void:
    p.line(a.x*factor,a.y*factor,b.x*factor,b.y*factor,_c(c))

func _foliage() -> void:
    # Blue-teal silhouettes, kept within the side ruins and below the main focal point.
    var anchors := [Vector2(96,329),Vector2(143,329),Vector2(235,329),Vector2(412,329),Vector2(500,329),Vector2(548,329)]
    for i in range(anchors.size()):
        var p = P.new(int(36*factor),int(24*factor))
        # Grounded branching fan inspired by weather/fireflies.js; individual leaf clusters.
        for j in range(8):
            var x: float = 5.0+j*3.5+_r(i*10+j,501)*2.0
            var y: float = 8.0+_r(i*10+j,502)*8.0 - 5.0*sin(PI*j/7.0)
            var mid := Vector2(18.0+(x-18.0)*0.55,17.0)
            _twig(p,Vector2(18,22),mid,"102d3c")
            _twig(p,mid,Vector2(x,y),"1c4252")
            for k in range(3):
                var lx: float = lerpf(mid.x,x,0.42+k*0.27)+(1.5 if k%2==0 else -1.5)
                var ly: float = lerpf(mid.y,y,0.42+k*0.27)
                p.ellipse(lx*factor,ly*factor,2.5*factor,1.7*factor,_c("123744"))
                p.ellipse((lx-0.8)*factor,(ly-0.7)*factor,1.6*factor,0.9*factor,_c(["26576a","1c4858","367184"][(i+j+k)%3]))
        var shrub := _local_sprite(_local_texture(p),anchors[i],"Shrub_%d"%i,Vector2(-18,-22))
        var mat := ShaderMaterial.new()
        mat.shader = SHRUB_SHADER
        shrub.material = mat
        shrubs.append(shrub)
    var leaf_p = P.new(int(8*factor),int(6*factor))
    leaf_p.poly([[1*factor,3*factor],[4*factor,1*factor],[7*factor,2*factor],[5*factor,5*factor],[2*factor,4*factor]],_c("4d8b99"))
    leaf_p.line(2*factor,3*factor,5*factor,2*factor,_c("85b7b7"))
    var tex := _local_texture(leaf_p)
    # Sparse wind trails stay beside ruins, away from the central fighting space.
    for i in range(5):
        var anchor := Vector2(90.0+_r(i,600)*105.0 if i<3 else 426.0+_r(i,600)*100.0, 308.0+_r(i,601)*13.0)
        var leaf := _local_sprite(tex,anchor,"WindLeaf_%d"%i,Vector2(-4,-3))
        leaves.append(leaf)
        leaf_anchors.append(anchor)
