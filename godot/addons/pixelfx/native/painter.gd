extends RefCounted
## Partial direct port of src/core/painter.js. CPU reference, not yet optimized.
## Original MIT: Patch, Hugo Duprez, 2026.
## Unsigned packed RGBA in 64-bit slots; separate additive RGB.
const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
var width: int
var height: int
var ox: int
var oy: int
var color := PackedInt64Array()
var light := PackedInt64Array()
var tx: float = 0.0
var ty: float = 0.0
var mirror: float = 1.0
var cs: float = 1.0
var sn: float = 0.0
var fade: float = 1.0
var light_k: float = 1.0

func _init(w: int, h: int, x: int = 0, y: int = 0) -> void:
    width = w
    height = h
    ox = x
    oy = y
    color.resize(w*h)
    light.resize(w*h)

func clear() -> void:
    color.fill(0)
    light.fill(0)

func place(x: float, y: float, flip: bool = false, angle: float = 0.0) -> void:
    tx = x
    ty = y
    mirror = -1.0 if flip else 1.0
    cs = cos(angle)
    sn = sin(angle)

func to_x(x: float,y: float) -> float:
    return tx + x * mirror * cs - y * sn

func to_y(x: float,y: float) -> float:
    return ty + x * mirror * sn + y * cs

func cell_x(x: float,y: float) -> int:
    return int(floor(to_x(floor(x)+0.5,floor(y)+0.5)))

func cell_y(x: float,y: float) -> int:
    return int(floor(to_y(floor(x)+0.5,floor(y)+0.5)))

func _index(sx: int, sy: int) -> int:
    var x: int = sx-ox
    var y: int = sy-oy
    if x<0 or y<0 or x>=width or y>=height:
        return -1
    return y*width+x

func put(sx: int,sy: int,c: int,a: float=1.0) -> void:
    if c == 0:
        return
    a *= fade
    if a < 1.0 and a <= (float(BAYER[((sy & 3)<<2)|(sx & 3)])+0.5)/16.0:
        return
    var i: int = _index(sx,sy)
    if i>=0:
        color[i]=c & 0xffffffff

func add(sx: int,sy: int,c: int,k: float=1.0) -> void:
    k *= fade*light_k
    if k<=0.004:
        return
    var i: int = _index(sx,sy)
    if i<0:
        return
    var d: int = light[i]
    var r: int = int(minf(255,(d&255)+(c&255)*k))
    var g: int = int(minf(255,((d>>8)&255)+((c>>8)&255)*k))
    var b: int = int(minf(255,((d>>16)&255)+((c>>16)&255)*k))
    light[i]=0xff000000|(b<<16)|(g<<8)|r

func blend_px(sx: int,sy: int,c: int,a: float) -> void:
    a *= fade
    if c==0 or a<=0.004:
        return
    var i: int = _index(sx,sy)
    if i<0:
        return
    var d: int = color[i]
    var da: float = float((d>>24)&255)/255.0
    var oa: float = a+da*(1.0-a)
    var k: float = a/oa
    var r: int = int((c&255)*k+(d&255)*(1.0-k))&255
    var g: int = int(((c>>8)&255)*k+((d>>8)&255)*(1.0-k))&255
    var b: int = int(((c>>16)&255)*k+((d>>16)&255)*(1.0-k))&255
    color[i]=((int(oa*255)&255)<<24)|(b<<16)|(g<<8)|r

func px(x: float,y: float,c: int) -> void:
    put(cell_x(x,y),cell_y(x,y),c)

func dot(x: float,y: float,c: int,a: float=1.0) -> void:
    if a>0.0:
        put(cell_x(x,y),cell_y(x,y),c,a)

func blend(x: float,y: float,c: int,a: float) -> void:
    blend_px(cell_x(x,y),cell_y(x,y),c,a)

func line(x0: float,y0: float,x1: float,y1: float,c: int,a: float=1.0) -> void:
    var sx: int = cell_x(x0,y0)
    var sy: int = cell_y(x0,y0)
    var ex: int = cell_x(x1,y1)
    var ey: int = cell_y(x1,y1)
    var dx: int = absi(ex-sx)
    var dy: int = -absi(ey-sy)
    var stepx: int = 1 if sx<ex else -1
    var stepy: int = 1 if sy<ey else -1
    var err: int = dx+dy
    while true:
        put(sx,sy,c,a)
        if sx==ex and sy==ey:
            break
        var e2: int = 2*err
        if e2>=dy:
            err+=dy
            sx+=stepx
        if e2<=dx:
            err+=dx
            sy+=stepy

func glow(x: float,y: float,r: float,c: int,k: float=0.5) -> void:
    if r<1.0 or k<=0.004:
        return
    var cx: float = to_x(x,y)
    var cy: float = to_y(x,y)
    # Clipping invisible iterations does not change the reference pixels.
    for sy in range(maxi(oy,int(floor(cy-r))),mini(oy+height-1,int(ceil(cy+r)))+1):
        var dy: float = (sy+0.5-cy)/r
        for sx in range(maxi(ox,int(floor(cx-r))),mini(ox+width-1,int(ceil(cx+r)))+1):
            var dx: float = (sx+0.5-cx)/r
            var d: float = dx*dx+dy*dy
            if d>=1.0:
                continue
            var f: float = 1.0-sqrt(d)
            add(sx,sy,c,f*f*k)

func rgba_bytes(is_light: bool=false) -> PackedByteArray:
    var out := PackedByteArray()
    out.resize(width*height*4)
    var src: PackedInt64Array = light if is_light else color
    for i in range(src.size()):
        var c: int = src[i]
        var j: int = i*4
        out[j]=c&255
        out[j+1]=(c>>8)&255
        out[j+2]=(c>>16)&255
        out[j+3]=255 if is_light else (c>>24)&255
    return out
