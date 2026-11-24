extends RefCounted
## Partial direct port of src/core/painter.js. CPU reference, not yet optimized.
## Original MIT: Patch, Hugo Duprez, 2026.
## Signed packed int32 slots retain exact RGBA bits; direct native byte conversion.
## Little-endian target (Windows/Linux x86-64). Empty light has alpha zero and RGB zero.
const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
var width: int
var height: int
var ox: int
var oy: int
var color := PackedInt32Array()
var light := PackedInt32Array()
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
        var bits: int = c & 0xffffffff
        color[i]=bits-0x100000000 if bits>=0x80000000 else bits

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
    light[i]=-16777216|(b<<16)|(g<<8)|r

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
    var bits: int=((int(oa*255)&255)<<24)|(b<<16)|(g<<8)|r
    color[i]=bits-0x100000000 if bits>=0x80000000 else bits

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
    var sx0: int = maxi(ox,int(floor(cx-r)))
    var sx1: int = mini(ox+width-1,int(ceil(cx+r)))
    var sy0: int = maxi(oy,int(floor(cy-r)))
    var sy1: int = mini(oy+height-1,int(ceil(cy+r)))
    var cr: int=c&255
    var cg: int=(c>>8)&255
    var cb: int=(c>>16)&255
    var factor: float=fade*light_k
    # Inlined add() on already clipped pixels; exact same truncation and threshold.
    for sy in range(sy0,sy1+1):
        var dy: float=(sy+0.5-cy)/r
        var dy2: float=dy*dy
        var row: int=(sy-oy)*width-ox
        for sx in range(sx0,sx1+1):
            var dx: float=(sx+0.5-cx)/r
            var d: float=dx*dx+dy2
            if d>=1.0:
                continue
            var f: float=1.0-sqrt(d)
            var strength: float=f*f*k
            strength*=factor
            if strength<=0.004:
                continue
            var i: int=row+sx
            var prior: int=light[i]
            var rr: int=int(minf(255,(prior&255)+cr*strength))
            var gg: int=int(minf(255,((prior>>8)&255)+cg*strength))
            var bb: int=int(minf(255,((prior>>16)&255)+cb*strength))
            light[i]=-16777216|(bb<<16)|(gg<<8)|rr

func rgba_bytes(is_light: bool=false) -> PackedByteArray:
    # PackedInt32Array.to_byte_array is an engine-native bulk conversion.
    # No per-pixel GDScript allocation/conversion. Zero light is transparent black.
    return light.to_byte_array() if is_light else color.to_byte_array()

# Constant-color shape subset of upstream Painter; pixel centers, not antialiased geometry.
func _bounds(x0: float,y0: float,x1: float,y1: float) -> Rect2i:
    var ax: float=INF
    var ay: float=INF
    var bx: float=-INF
    var by: float=-INF
    for k in range(4):
        var x: float=x1 if (k&1)!=0 else x0
        var y: float=y1 if (k&2)!=0 else y0
        var sx: float=to_x(x,y)
        var sy: float=to_y(x,y)
        ax=minf(ax,sx)
        ay=minf(ay,sy)
        bx=maxf(bx,sx)
        by=maxf(by,sy)
    var left: int=maxi(ox,int(floor(ax)))
    var top: int=maxi(oy,int(floor(ay)))
    var right: int=mini(ox+width-1,int(ceil(bx)))
    var bottom: int=mini(oy+height-1,int(ceil(by)))
    return Rect2i(left,top,maxi(0,right-left+1),maxi(0,bottom-top+1))

func from_x(sx: float,sy: float) -> float:
    return ((sx-tx)*cs+(sy-ty)*sn)*mirror

func from_y(sx: float,sy: float) -> float:
    return -(sx-tx)*sn+(sy-ty)*cs

func _radial(cx: float,cy: float,rx: float,ry: float,c: int,a: float,soft: bool,inner: float=0.0) -> void:
    if rx<=0.0 or ry<=0.0:
        return
    var box: Rect2i=_bounds(cx-rx,cy-ry,cx+rx,cy+ry)
    for sy in range(box.position.y,box.end.y):
        for sx in range(box.position.x,box.end.x):
            var dx: float=from_x(sx+0.5,sy+0.5)-cx
            var dy: float=from_y(sx+0.5,sy+0.5)-cy
            # For circles use original unnormalized comparison; ellipses normalize first.
            var d2: float=dx*dx+dy*dy if rx==ry else (dx/rx)*(dx/rx)+(dy/ry)*(dy/ry)
            var limit: float=rx*rx if rx==ry else 1.0
            if d2>limit or d2<inner*inner:
                continue
            if soft:
                blend_px(sx,sy,c,a)
            else:
                put(sx,sy,c,a)

func circle(cx: float,cy: float,r: float,c: int,a: float=1.0) -> void:
    if r<0.6:
        dot(cx,cy,c,a)
    else:
        _radial(cx,cy,r,r,c,a,false)

func disc(cx: float,cy: float,r: float,c: int,a: float) -> void:
    if r<0.5:
        blend(cx,cy,c,a)
    else:
        _radial(cx,cy,r,r,c,a,true)

func ellipse(cx: float,cy: float,rx: float,ry: float,c: int,a: float=1.0) -> void:
    # Upstream normalizes even if radii are equal; preserve that ordering.
    if rx<=0.0 or ry<=0.0:
        return
    var box: Rect2i=_bounds(cx-rx,cy-ry,cx+rx,cy+ry)
    for sy in range(box.position.y,box.end.y):
        for sx in range(box.position.x,box.end.x):
            var dx: float=(from_x(sx+0.5,sy+0.5)-cx)/rx
            var dy: float=(from_y(sx+0.5,sy+0.5)-cy)/ry
            if dx*dx+dy*dy<=1.0:
                put(sx,sy,c,a)

func ring(cx: float,cy: float,r: float,w: float,c: int,a: float=1.0) -> void:
    _radial(cx,cy,r,r,c,a,false,maxf(0.0,r-w))

func rect(x: float,y: float,w: float,h: float,c: int,a: float=1.0) -> void:
    if sn==0.0:
        for yy in range(int(floor(y+0.5)),int(floor(y+h+0.5))):
            for xx in range(int(floor(x+0.5)),int(floor(x+w+0.5))):
                put(cell_x(xx,yy),cell_y(xx,yy),c,a)
        return
    var box: Rect2i=_bounds(x,y,x+w,y+h)
    for sy in range(box.position.y,box.end.y):
        for sx in range(box.position.x,box.end.x):
            var lx: float=from_x(sx+0.5,sy+0.5)
            var ly: float=from_y(sx+0.5,sy+0.5)
            if lx>=x and ly>=y and lx<x+w and ly<y+h:
                put(sx,sy,c,a)

func beam(x0: float,y0: float,x1: float,y1: float,w: float,c: int,a: float=1.0) -> void:
    var r: float=w/2.0
    var dx: float=x1-x0
    var dy: float=y1-y0
    var l2: float=dx*dx+dy*dy
    if l2==0.0:
        l2=0.000000001
    var box: Rect2i=_bounds(minf(x0,x1)-r,minf(y0,y1)-r,maxf(x0,x1)+r,maxf(y0,y1)+r)
    for sy in range(box.position.y,box.end.y):
        for sx in range(box.position.x,box.end.x):
            var x: float=from_x(sx+0.5,sy+0.5)
            var y: float=from_y(sx+0.5,sy+0.5)
            var u: float=clampf(((x-x0)*dx+(y-y0)*dy)/l2,0.0,1.0)
            var px0: float=x0+dx*u-x
            var py0: float=y0+dy*u-y
            if px0*px0+py0*py0<=r*r:
                put(sx,sy,c,a)
