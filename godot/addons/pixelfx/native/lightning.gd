extends RefCounted
## Direct algorithm port of zigzag/bowed/stroke/crackle from lightning/_lib.js.
## Original MIT: Patch, Hugo Duprez, 2026. CPU reference pending parity/benchmark.
## Local positions are double-precision Arrays rather than Vector2 to match JS.
const N: int = 1024
const HALF: int = 512
const VOLT = ["#120a33","#2a1b78","#4630c0","#5a62f0","#58a6ff","#9ed8ff","#e4f6ff","#ffffff"]
const CROSS = [[1,0],[-1,0],[0,1],[0,-1]]
var grid := PackedByteArray()
var hits := PackedInt32Array()
var accelerator: Object
var accelerated_calls: int=0
var rejected_calls: int=0

func enable_acceleration(enabled: bool=true) -> bool:
    accelerator=null
    if enabled and ClassDB.class_exists("PixelFXRaster"):
        accelerator=ClassDB.instantiate("PixelFXRaster")
    return accelerator!=null

func _fast(p,paths: Array,k: float,c: Array,s: float,o: Dictionary,thin: bool) -> bool:
    if accelerator==null:
        return false
    var cfg:=PackedFloat64Array([p.width,p.height,p.ox,p.oy,p.tx,p.ty,p.mirror,p.cs,p.sn,p.fade,p.light_k])
    var buffers: Array=accelerator.render_bolt(p.color,p.light,cfg,paths,c,k,s,o,thin)
    if buffers.size()!=2:
        rejected_calls+=1
        return false
    accelerated_calls+=1
    p.color=buffers[0]
    p.light=buffers[1]
    return true

func _init() -> void:
    grid.resize(N*N)

static func zigzag(rng, x0: float,y0: float,x1: float,y1: float,jag: float=0.32,forks: float=0.35,w: float=1.0,depth: int=0) -> Array:
    var length: float = sqrt(pow(x1-x0,2)+pow(y1-y0,2))
    var pts: Array = [[x0,y0],[x1,y1]]
    var off: float = length*jag
    while pts.size()<2.0+length/3.0:
        var nxt: Array = [pts[0]]
        for i in range(pts.size()-1):
            var ax: float = pts[i][0]
            var ay: float = pts[i][1]
            var bx: float = pts[i+1][0]
            var by: float = pts[i+1][1]
            var l: float = sqrt(pow(bx-ax,2)+pow(by-ay,2))
            if l==0.0:
                l=1.0
            var o: float = rng.between(-off,off)
            nxt.append([(ax+bx)/2.0+(-(by-ay)/l)*o,(ay+by)/2.0+((bx-ax)/l)*o])
            nxt.append(pts[i+1])
        pts=nxt
        off*=0.52
    var paths: Array = [{"pts":pts,"w":w}]
    if depth<2:
        for i in range(2,pts.size()-3):
            if rng.chance(forks/(1.0+depth)/maxf(4.0,pts.size()/6.0)):
                var ax: float=pts[i][0]
                var ay: float=pts[i][1]
                var b: Array=pts[mini(pts.size()-1,i+3)]
                var a: float=atan2(b[1]-ay,b[0]-ax)+rng.sign()*rng.between(0.35,0.9)
                var l: float=(length-float(i)/pts.size()*length)*rng.between(0.25,0.55)
                paths.append_array(zigzag(rng,ax,ay,ax+cos(a)*l,ay+sin(a)*l,jag*1.1,forks,w*0.55,depth+1))
    return paths

static func bowed(rng,x0: float,y0: float,x1: float,y1: float,bow: float,jag: float=0.22,forks: float=0.4) -> Array:
    var l: float=sqrt(pow(x1-x0,2)+pow(y1-y0,2))
    if l==0.0:
        l=1.0
    var mx: float=(x0+x1)/2.0-(y1-y0)/l*bow+rng.between(-2.0,2.0)
    var my: float=(y0+y1)/2.0+(x1-x0)/l*bow
    var a: Array=zigzag(rng,x0,y0,mx,my,jag,forks)
    var b: Array=zigzag(rng,mx,my,x1,y1,jag,forks)
    var pts: Array=a[0]["pts"]+b[0]["pts"].slice(1)
    return [{"pts":pts,"w":1.0}]+a.slice(1)+b.slice(1)

func _mark(x: float,y: float,lvl: int) -> void:
    var ix: int=int(floor(x))+HALF
    var iy: int=int(floor(y))+HALF
    if ix<0 or iy<0 or ix>=N or iy>=N:
        return
    var i: int=iy*N+ix
    var v: int=grid[i]
    if v==0:
        hits.append(i)
    if lvl>v:
        grid[i]=lvl

func _stamp(x: float,y: float,r: float,lvl: int) -> void:
    if r<=0.5:
        _mark(floor(x+0.5),floor(y+0.5),lvl)
        return
    var r2: float=r*r
    for py in range(int(floor(y-r)),int(ceil(y+r))+1):
        var dy: float=py+0.5-y
        for px in range(int(floor(x-r)),int(ceil(x+r))+1):
            var dx: float=px+0.5-x
            if dx*dx+dy*dy<=r2:
                _mark(px,py,lvl)

func _flush(p,cols: Array,alphas: Array) -> void:
    for i in hits:
        var v: int=grid[i]
        grid[i]=0
        var x: int=i%N-HALF
        var y: int=int(floor(float(i)/N))-HALF
        var a: float=alphas[v-1]
        if a>=1.0:
            p.px(x,y,cols[v-1])
        elif a>0.0:
            p.dot(x,y,cols[v-1],a)
    hits.clear()

func stroke(p,paths: Array,k: float,c: Array,s: float=1.0,o: Dictionary={}) -> void:
    if k<=0.02:
        return
    if _fast(p,paths,k,c,s,o,false):
        return
    var lk: float=o.get("light",0.5)
    for q in paths:
        var trunk: bool=float(q["w"])>=1.0
        if not trunk and k<0.5:
            continue
        var rh: float=((2.1 if k>0.6 else 1.6) if trunk else 1.1)*s
        var rb: float=((1.3 if k>0.6 else 0.8) if trunk else 0.5)*s
        var pts: Array=q["pts"]
        if o.has("upTo") and trunk:
            pts=pts.slice(0,maxi(2,int(ceil(pts.size()*float(o["upTo"])))))
        for i in range(pts.size()-1):
            var ax: float=pts[i][0]
            var ay: float=pts[i][1]
            var bx: float=pts[i+1][0]
            var by: float=pts[i+1][1]
            var l: float=maxf(1.0,sqrt(pow(bx-ax,2)+pow(by-ay,2)))
            var d: float=0.0
            while d<=l:
                var x: float=ax+(bx-ax)*d/l
                var y: float=ay+(by-ay)*d/l
                _stamp(x,y,rh,1)
                _stamp(x,y,rb,3 if trunk else 2)
                if trunk and k>0.3:
                    if float(o.get("core",0.0))!=0.0:
                        _stamp(x,y,float(o["core"]),4)
                    else:
                        _mark(x,y,4)
                d+=0.5
        for i in range(0,pts.size()-1,3):
            if not o.has("minY") or float(pts[i][1])>float(o["minY"]):
                p.glow(pts[i][0],pts[i][1],(14.0 if trunk else 7.0)*s,c[4],lk*k*float(q["w"]))
    var a: float=o.get("a",1.0)
    _flush(p,[c[3],c[6],c[7],c[7]] if o.get("hero",false) else [c[2],c[4],c[5],c[7]],[a,a,a,a])

func crackle(p,paths: Array,k: float,c: Array,glow_k: float=0.5,a: float=1.0) -> void:
    if k<=0.02:
        return
    if _fast(p,paths,k,c,1.0,{"light":glow_k,"a":a},true):
        return
    for q in paths:
        var thick: bool=float(q["w"])>=1.0
        var pts: Array=q["pts"]
        for i in range(pts.size()-1):
            var ax: float=pts[i][0]
            var ay: float=pts[i][1]
            var bx: float=pts[i+1][0]
            var by: float=pts[i+1][1]
            var l: float=maxf(1.0,sqrt(pow(bx-ax,2)+pow(by-ay,2)))
            var d: float=0.0
            while d<=l:
                var x: float=ax+(bx-ax)*d/l
                var y: float=ay+(by-ay)*d/l
                if k>0.45 and thick:
                    for v in CROSS:
                        _mark(x+v[0]*1.5,y+v[1]*1.5,1)
                if k>0.25 and (thick or float(q["w"])>0.4):
                    _mark(x+1.0,y,2)
                    _mark(x,y+1.0,2)
                _mark(x,y,4 if thick and k>0.3 else 3)
                d+=0.5
        for i in range(0,pts.size()-1,3):
            p.glow(pts[i][0],pts[i][1],(9.0 if thick else 5.0)*(0.5+k*0.5),c[4],glow_k*k*float(q["w"]))
    _flush(p,[c[3],c[5],c[5],c[7]],[minf(1.0,(k-0.45)*1.6)*a,a,a,a])

static func trace(p,pts: Array,c: int,a: float=1.0,from_index: int=0,to_index: int=-1) -> void:
    var last: int=pts.size()-1 if to_index<0 else mini(to_index,pts.size()-1)
    for i in range(maxi(0,from_index),last):
        p.line(pts[i][0],pts[i][1],pts[i+1][0],pts[i+1][1],c,a)

static func scorch(p,cx: float,cy: float,rx: float,t0: float,fade: float=1.0,ry: float=-1.0) -> void:
    if fade<=0 or rx<=0:
        return
    if ry<0:
        ry=maxf(2.5,rx*.12)
    const PAL=preload("res://addons/pixelfx/native/palette.gd")
    const R=preload("res://addons/pixelfx/native/rng.gd")
    const P=preload("res://addons/pixelfx/native/particles.gd")
    var ramp: Array=PAL.fit(P.FIRE_HEX,P.FIRE_HEX.size())
    var soot: int=PAL.from_hex("#110c16")
    var soot2: int=PAL.from_hex("#1c1522")
    for y in range(int(floor(cy)),int(floor(cy+ry))+1):
        for x in range(int(floor(cx-rx)),int(ceil(cx+rx))+1):
            var dx: float=(x+.5-cx)/rx
            var dy: float=(y+.5-cy)/ry
            var d: float=sqrt(dx*dx+dy*dy)
            if d>1:
                continue
            var n: float=float(R.hash32([x,y,41]))/4294967296.0
            var temp: float=t0*(1.25-d)-n*.35
            if temp>.06:
                var c: int=ramp[mini(ramp.size()-1,int(floor((1-minf(1,temp))*(ramp.size()-1))))]
                p.dot(x,y,c,fade)
                if (x&3)==0:
                    p.glow(x+.5,y,6,c,.18*temp*fade)
            else:
                p.dot(x,y,soot if d<.5 else soot2,(1.0 if d<.95-n*.3 else 1-d)*fade)
