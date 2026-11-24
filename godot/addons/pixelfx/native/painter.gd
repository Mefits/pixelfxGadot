extends RefCounted
## Direct port of src/core/painter.js. CPU reference, not yet optimized.
## Original MIT: Patch, Hugo Duprez, 2026.
## Signed packed int32 slots retain exact RGBA bits; direct native byte conversion.
## Little-endian target (Windows/Linux x86-64). Empty light has alpha zero and RGB zero.
const FONT=preload("res://addons/pixelfx/native/font.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
var layer: String="front"
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

func line(x0: float,y0: float,x1: float,y1: float,c: Variant,a: Variant=1.0) -> void:
    var sx: int = cell_x(x0,y0)
    var sy: int = cell_y(x0,y0)
    var ex: int = cell_x(x1,y1)
    var ey: int = cell_y(x1,y1)
    var dx: int = absi(ex-sx)
    var dy: int = -absi(ey-sy)
    var stepx: int = 1 if sx<ex else -1
    var stepy: int = 1 if sy<ey else -1
    var err: int = dx+dy
    var n: int=maxi(1,maxi(dx,-dy))
    var step: int=0
    var dynamic: bool=c is Callable or a is Callable
    while true:
        if dynamic:
            var u: float=float(step)/n
            put(sx,sy,int(_value(c,[u])),float(_value(a,[u])))
        else:
            put(sx,sy,c,a)
        step+=1
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

func circle(cx: float,cy: float,r: float,c: Variant,a: Variant=1.0) -> void:
    if c is Callable or a is Callable:
        _circle_callback(cx,cy,r,c,a,false)
        return
    if r<0.6:
        dot(cx,cy,c,a)
    else:
        _radial(cx,cy,r,r,c,a,false)

func disc(cx: float,cy: float,r: float,c: Variant,a: Variant) -> void:
    if c is Callable or a is Callable:
        _circle_callback(cx,cy,r,c,a,true)
        return
    if r<0.5:
        blend(cx,cy,c,a)
    else:
        _radial(cx,cy,r,r,c,a,true)

func ellipse(cx: float,cy: float,rx: float,ry: float,c: Variant,a: Variant=1.0) -> void:
    if c is Callable or a is Callable:
        _ellipse_callback(cx,cy,rx,ry,c,a)
        return
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

func ring(cx: float,cy: float,r: float,w: float,c: Variant,a: Variant=1.0) -> void:
    if c is Callable or a is Callable:
        _ring_callback(cx,cy,r,w,c,a)
        return
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

func beam(x0: float,y0: float,x1: float,y1: float,w: float,c: Variant,a: Variant=1.0) -> void:
    if c is Callable or a is Callable:
        _beam_callback(x0,y0,x1,y1,w,c,a)
        return
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

# Dynamic shader/shape callbacks mirror upstream coordinate conventions.
static func _value(v: Variant,args: Array) -> Variant:
    return v.callv(args) if v is Callable else v

func reset() -> void:
    place(0,0)
    fade=1.0
    light_k=1.0
    layer="front"

func get_color(x: float,y: float) -> int:
    var i: int=_index(cell_x(x,y),cell_y(x,y))
    return (color[i]&0xffffffff) if i>=0 else 0

func light_pixel(x: float,y: float,c: int,k: float=1.0) -> void:
    add(cell_x(x,y),cell_y(x,y),c,k)

func each(x0: float,y0: float,x1: float,y1: float,fn: Callable) -> void:
    var b: Rect2i=_bounds(x0,y0,x1,y1)
    for sy in range(b.position.y,b.end.y):
        for sx in range(b.position.x,b.end.x):
            fn.call(from_x(sx+0.5,sy+0.5),from_y(sx+0.5,sy+0.5),sx,sy)

func shade(x0: float,y0: float,x1: float,y1: float,fn: Callable) -> void:
    var o: Dictionary={}
    each(x0,y0,x1,y1,func(x: float,y: float,sx: int,sy: int):
        o["c"]=0
        o["a"]=1.0
        o["l"]=0
        o["k"]=0.0
        var result: Variant=fn.call(x,y,o)
        var c: int=int(result) if result!=null and result!=0 else int(o["c"])
        if c!=0:
            put(sx,sy,c,o["a"])
        if float(o["k"])>0.0:
            add(sx,sy,int(o["l"]) if int(o["l"])!=0 else c,o["k"])
    )

func polyline(pts: Array,c: Variant,a: Variant=1.0) -> void:
    for i in range(1,pts.size()):
        line(pts[i-1][0],pts[i-1][1],pts[i][0],pts[i][1],c,a)

func _circle_callback(cx: float,cy: float,r: float,c: Variant,a: Variant,soft: bool) -> void:
    if r<(0.5 if soft else 0.6):
        var col: int=int(_value(c,[0.0,0.0]))
        var alpha: float=float(_value(a,[0.0,0.0]))
        if soft:
            blend(cx,cy,col,alpha)
        else:
            dot(cx,cy,col,alpha)
        return
    each(cx-r,cy-r,cx+r,cy+r,func(x: float,y: float,sx: int,sy: int):
        var dx: float=x-cx
        var dy: float=y-cy
        var d2: float=dx*dx+dy*dy
        if d2>r*r:
            return
        var args: Array=[sqrt(d2)/r,atan2(dy,dx)]
        var col: int=int(_value(c,args))
        var alpha: float=float(_value(a,args))
        if soft:
            blend_px(sx,sy,col,alpha)
        else:
            put(sx,sy,col,alpha)
    )

func _ellipse_callback(cx: float,cy: float,rx: float,ry: float,c: Variant,a: Variant) -> void:
    if rx<=0.0 or ry<=0.0:
        return
    each(cx-rx,cy-ry,cx+rx,cy+ry,func(x: float,y: float,sx: int,sy: int):
        var dx: float=(x-cx)/rx
        var dy: float=(y-cy)/ry
        var d2: float=dx*dx+dy*dy
        if d2<=1.0:
            var args: Array=[sqrt(d2),atan2(dy,dx)]
            put(sx,sy,int(_value(c,args)),float(_value(a,args)))
    )

func _ring_callback(cx: float,cy: float,r: float,w: float,c: Variant,a: Variant) -> void:
    var r0: float=maxf(0,r-w)
    each(cx-r,cy-r,cx+r,cy+r,func(x: float,y: float,sx: int,sy: int):
        var dx: float=x-cx
        var dy: float=y-cy
        var d2: float=dx*dx+dy*dy
        if d2>r*r or d2<r0*r0:
            return
        var denom: float=r-r0 if r!=r0 else 1.0
        var v: float=(sqrt(d2)-r0)/denom if w>0 else 1.0
        var args: Array=[v,atan2(dy,dx)]
        put(sx,sy,int(_value(c,args)),float(_value(a,args)))
    )

func _beam_callback(x0: float,y0: float,x1: float,y1: float,w: float,c: Variant,a: Variant) -> void:
    var r: float=w/2.0
    var dx: float=x1-x0
    var dy: float=y1-y0
    var l2: float=dx*dx+dy*dy
    if l2==0:
        l2=0.000000001
    each(minf(x0,x1)-r,minf(y0,y1)-r,maxf(x0,x1)+r,maxf(y0,y1)+r,func(x: float,y: float,sx: int,sy: int):
        var u: float=clampf(((x-x0)*dx+(y-y0)*dy)/l2,0,1)
        var ex: float=x0+dx*u-x
        var ey: float=y0+dy*u-y
        var d2: float=ex*ex+ey*ey
        if d2<=r*r and r>0:
            var args: Array=[u,sqrt(d2)/r]
            put(sx,sy,int(_value(c,args)),float(_value(a,args)))
    )

func arc(cx: float,cy: float,r: float,w: Variant,a0: float,a1: float,c: Variant,a: Variant=1.0) -> void:
    var span: float=a1-a0
    if span<=0:
        return
    each(cx-r,cy-r,cx+r,cy+r,func(x: float,y: float,sx: int,sy: int):
        var dx: float=x-cx
        var dy: float=y-cy
        var d: float=sqrt(dx*dx+dy*dy)
        if d>r:
            return
        var ang: float=atan2(dy,dx)-a0
        ang-=floor(ang/TAU)*TAU
        if ang>span:
            return
        var u: float=ang/span
        var ww: float=float(_value(w,[u]))
        if ww<=0 or d<r-ww:
            return
        var args: Array=[u,(d-(r-ww))/ww]
        put(sx,sy,int(_value(c,args)),float(_value(a,args)))
    )

func poly(pts: Array,c: Variant,a: Variant=1.0) -> void:
    if pts.size()<3:
        return
    var x0: float=INF
    var y0: float=INF
    var x1: float=-INF
    var y1: float=-INF
    for q in pts:
        x0=minf(x0,q[0])
        y0=minf(y0,q[1])
        x1=maxf(x1,q[0])
        y1=maxf(y1,q[1])
    each(x0,y0,x1,y1,func(x: float,y: float,sx: int,sy: int):
        var inside: bool=false
        var j: int=pts.size()-1
        for i in range(pts.size()):
            var xi: float=pts[i][0]
            var yi: float=pts[i][1]
            var xj: float=pts[j][0]
            var yj: float=pts[j][1]
            if (yi>y)!=(yj>y) and x<((xj-xi)*(y-yi))/(yj-yi)+xi:
                inside=not inside
            j=i
        if inside:
            put(sx,sy,int(_value(c,[x,y])),float(_value(a,[x,y])))
    )

func tri(x0: float,y0: float,x1: float,y1: float,x2: float,y2: float,c: Variant,a: Variant=1.0) -> void:
    poly([[x0,y0],[x1,y1],[x2,y2]],c,a)

func glow_line(x0: float,y0: float,x1: float,y1: float,r: float,c: int,k: float=0.5) -> void:
    if r<1 or k<=0.004:
        return
    var ax: float=to_x(x0,y0)
    var ay: float=to_y(x0,y0)
    var bx: float=to_x(x1,y1)
    var by: float=to_y(x1,y1)
    var dx: float=bx-ax
    var dy: float=by-ay
    var l2: float=dx*dx+dy*dy
    if l2==0:
        l2=0.000000001
    for sy in range(maxi(oy,int(floor(minf(ay,by)-r))),mini(oy+height-1,int(ceil(maxf(ay,by)+r)))+1):
        for sx in range(maxi(ox,int(floor(minf(ax,bx)-r))),mini(ox+width-1,int(ceil(maxf(ax,bx)+r)))+1):
            var px0: float=sx+0.5
            var py0: float=sy+0.5
            var u: float=clampf(((px0-ax)*dx+(py0-ay)*dy)/l2,0,1)
            var ex: float=ax+dx*u-px0
            var ey: float=ay+dy*u-py0
            var d: float=sqrt(ex*ex+ey*ey)/r
            if d<1:
                var f: float=1-d
                add(sx,sy,c,f*f*k)

func glow_ring(x: float,y: float,radius: float,r: float,c: int,k: float=0.5) -> void:
    if r<1 or k<=0.004:
        return
    var cx: float=to_x(x,y)
    var cy: float=to_y(x,y)
    var e: float=radius+r
    for sy in range(maxi(oy,int(floor(cy-e))),mini(oy+height-1,int(ceil(cy+e)))+1):
        for sx in range(maxi(ox,int(floor(cx-e))),mini(ox+width-1,int(ceil(cx+e)))+1):
            var dx: float=sx+0.5-cx
            var dy: float=sy+0.5-cy
            var d: float=absf(sqrt(dx*dx+dy*dy)-radius)/r
            if d<1:
                var f: float=1-d
                add(sx,sy,c,f*f*k)

func sprite(rows: Array,pal: Dictionary,x: float,y: float,opts: Dictionary={}) -> void:
    if rows.is_empty():
        return
    var k: float=opts.get("scale",1)
    var a: float=opts.get("a",1)
    var w: int=rows[0].length()
    var cache: Dictionary={}
    for r in range(rows.size()):
        for q in range(rows[r].length()):
            var ch: String=rows[r][q]
            if ch=="." or ch==" ":
                continue
            var col: int=0
            if opts.has("tint"):
                col=int(opts["tint"])
            else:
                if not cache.has(ch):
                    var v: Variant=pal.get(ch,0)
                    cache[ch]=PAL.from_hex(v) if v is String else int(v)
                col=cache[ch]
            if col==0:
                continue
            var xx: int=w-1-q if opts.get("flip",false) else q
            var yy: int=rows.size()-1-r if opts.get("flipY",false) else r
            if k==1:
                dot(x+xx,y+yy,col,a)
            else:
                rect(x+xx*k,y+yy*k,k,k,col,a)

func measure(value: String,opts: Dictionary={}) -> Array:
    var font: String=opts.get("font","mini")
    var k: float=opts.get("scale",1)
    return [FONT.text_width(value,font)*k,FONT.height(font)*k]

func text(value: String,x: float,y: float,c: Variant,opts: Dictionary={}) -> void:
    var font: String=opts.get("font","mini")
    var k: float=opts.get("scale",1)
    var a: float=opts.get("a",1)
    var w: float=FONT.text_width(value,font)*k
    var align: String=opts.get("align","left")
    var left: float=floor((x-w/2 if align=="center" else (x-w if align=="right" else x))+0.5)
    var top: float=floor(y+0.5)
    var pixels: Array=FONT.pixels(value,font)
    if opts.has("outline"):
        for q in pixels:
            rect(left+q[0]*k-1,top+q[1]*k-1,k+2,k+2,opts["outline"],a)
    if opts.has("shadow"):
        for q in pixels:
            rect(left+q[0]*k+1,top+q[1]*k+1,k,k,opts["shadow"],a)
    for q in pixels:
        rect(left+q[0]*k,top+q[1]*k,k,k,int(_value(c,q)),a)

static func _mask_at(m: Dictionary,x: int,y: int) -> bool:
    return x>=0 and y>=0 and x<int(m["w"]) and y<int(m["h"]) and bool(m["data"][y*int(m["w"])+x])

func mask(m: Dictionary,x: float,y: float,c: Variant,a: Variant=1.0) -> void:
    for yy in range(int(m["h"])):
        for xx in range(int(m["w"])):
            if _mask_at(m,xx,yy):
                dot(x+xx,y+yy,int(_value(c,[xx,yy])),float(_value(a,[xx,yy])))

func outline(m: Dictionary,x: float,y: float,c: Variant,a: Variant=1.0) -> void:
    for yy in range(-1,int(m["h"])+1):
        for xx in range(-1,int(m["w"])+1):
            if not _mask_at(m,xx,yy) and (_mask_at(m,xx-1,yy) or _mask_at(m,xx+1,yy) or _mask_at(m,xx,yy-1) or _mask_at(m,xx,yy+1)):
                dot(x+xx,y+yy,int(_value(c,[xx,yy])),float(_value(a,[xx,yy])))
