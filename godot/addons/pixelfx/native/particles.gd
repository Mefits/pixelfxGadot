extends RefCounted
## Direct reference port of the electrical/hard particle kinds from src/core/sim.js.
## Original MIT: Patch, Hugo Duprez, 2026. Adapted upstream from Sprite Fusion.
## Soft smoke, fire and vapour are not implemented yet.
const PAL = preload("res://addons/pixelfx/native/palette.gd")
const RNG = preload("res://addons/pixelfx/native/rng.gd")
const GRAVITY: float = 950.0
const SPARK: int = 0
const MOTE: int = 1
const STREAK: int = 2
const FLAKE: int = 3
const STAR: int = 6
const EMBER: int = 7
const GRIT: int = 11
const BACK: int = 4
const WHITE: int = 0xffffffff
const CROSS = [[1,0],[-1,0],[0,1],[0,-1]]
const DIAG = [[1,1],[1,-1],[-1,1],[-1,-1]]
var list: Array[Dictionary] = []
var t: float = 0.0
var rng
var ground: Callable
var sparks: Array = []
var capacity: int = 512

func _init(seed_value: int=1, ground_fn: Callable=Callable(), ramp: Array=[]) -> void:
    rng=RNG.new(seed_value)
    ground=ground_fn
    var source: Array = ramp if not ramp.is_empty() else ["#fff3a6","#ffe26b","#ff8a2a","#f2561d"]
    sparks=PAL.fit(source,source.size())

func floor_at(x: float) -> float:
    return float(ground.call(x)) if ground.is_valid() else INF

func spawn(kind: int,x: float,y: float,vx: float,vy: float,life: float,col: int=WHITE,size: float=1.0,delay: float=0.0,flag: int=0) -> bool:
    if kind not in [SPARK,MOTE,STREAK,FLAKE,STAR,EMBER,GRIT]:
        push_error("Particle kind not ported: "+str(kind))
        return false
    if list.size()>=capacity or life<=0.0:
        return false
    list.append({"k":kind,"x":x,"y":y,"vx":vx,"vy":vy,"life":life,"max":life,"col":col,"size":size,"seed":rng.next()*100.0,"delay":delay,"flag":flag})
    return true

func advance(dt: float) -> void:
    var n: int=maxi(1,int(ceil(dt*120.0-0.000000001)))
    for _i in range(n):
        update(dt/n)

func update(dt: float) -> void:
    t+=dt
    for i in range(list.size()-1,-1,-1):
        var p: Dictionary=list[i]
        if p["delay"]>0.0:
            p["delay"]-=dt
            continue
        p["life"]-=dt
        if p["life"]<=0.0:
            list.remove_at(i)
            continue
        match int(p["k"]):
            SPARK:
                p["vy"]+=GRAVITY*0.45*dt
                p["vx"]-=p["vx"]*2.2*dt
                p["vy"]-=p["vy"]*2.2*dt
                var g: float=floor_at(p["x"])
                var ny: float=p["y"]+p["vy"]*dt
                p["x"]+=p["vx"]*dt
                if p["vy"]>0.0 and p["y"]<=g and ny>=g:
                    p["vy"]=-p["vy"]*0.45
                    p["vx"]*=0.7
                    p["y"]=g-0.25
                else:
                    p["y"]=ny
                continue
            GRIT:
                p["vy"]+=GRAVITY*dt
                p["vx"]-=p["vx"]*0.8*dt
                var g: float=floor_at(p["x"])
                var ny: float=p["y"]+p["vy"]*dt
                p["x"]+=p["vx"]*dt
                if p["vy"]>0.0 and p["y"]<=g and ny>=g:
                    p["y"]=g-0.25
                    if p["vy"]>130.0 and rng.chance(0.4):
                        p["vy"]=-p["vy"]*0.25
                        p["vx"]=p["vx"]*0.5+rng.between(-10.0,10.0)
                    else:
                        p["vx"]=0.0
                        p["vy"]=0.0
                        p["life"]=minf(p["life"],0.5)
                else:
                    p["y"]=ny
                continue
            STREAK:
                p["vx"]+=p["vx"]*3.0*dt
                p["vy"]+=p["vy"]*3.0*dt
            FLAKE:
                p["vx"]-=p["vx"]*2.2*dt
                p["vy"]-=p["vy"]*2.2*dt-35.0*dt
                p["x"]+=sin(t*2.5+p["seed"])*7.0*dt
            EMBER:
                p["vy"]+=(-30.0+sin(t*3.0+p["seed"])*20.0)*dt
                p["vx"]+=cos(t*2.3+p["seed"])*45.0*dt
                p["vx"]-=p["vx"]*1.6*dt
                p["vy"]-=p["vy"]*1.6*dt
            MOTE:
                p["vx"]-=p["vx"]*0.6*dt
                p["vy"]-=p["vy"]*0.6*dt
            _:
                p["vx"]-=p["vx"]*1.6*dt
                p["vy"]-=p["vy"]*1.6*dt+5.0*dt
        p["x"]+=p["vx"]*dt
        p["y"]+=p["vy"]*dt

static func sparkle(p,x: float,y: float,arm: float,c: int,tip: int,k: float=0.6) -> void:
    var n: int=int(floor(arm+0.5))
    if n<1:
        return
    var xx: int=int(floor(x))
    var yy: int=int(floor(y))
    for d in range(1,n+1):
        var cc: int=tip if d>n*0.6 else c
        for v in CROSS:
            p.px(xx+v[0]*d,yy+v[1]*d,cc)
    if n>=3:
        for v in DIAG:
            p.px(xx+v[0],yy+v[1],c)
    if n>=6:
        for v in DIAG:
            p.px(xx+v[0]*2,yy+v[1]*2,tip)
    p.px(xx,yy,WHITE)
    p.glow(x,y,4+n*2,c,k)

func draw(p,layer: String="") -> void:
    for q in list:
        if q["delay"]>0.0:
            continue
        var back: bool=(int(q["flag"])&BACK)!=0
        if layer!="" and layer!=("back" if back else "front"):
            continue
        var k: float=q["life"]/q["max"]
        var x: float=q["x"]
        var y: float=q["y"]
        var sp: float=sqrt(pow(q["vx"],2)+pow(q["vy"],2))
        if sp==0.0:
            sp=1.0
        var ux: float=q["vx"]/sp
        var uy: float=q["vy"]/sp
        var col: int=q["col"]
        var size: float=q["size"]
        match int(q["k"]):
            SPARK:
                var head: int=sparks[0] if k>0.6 else (sparks[1] if k>0.3 else sparks[2])
                var length: float=minf(9.0,1.0+sp*0.022)
                p.line(x-ux*length,y-uy*length,x-ux*length*0.4,y-uy*length*0.4,head if k>0.5 else sparks[-1])
                p.line(x-ux*length*0.45,y-uy*length*0.45,x,y,head)
                p.glow(x,y,3.0,head,0.45*k)
            MOTE:
                var length: float=minf(16.0,0.5+sp*0.026)*size
                var a: float=k/0.35 if k<0.35 else 1.0
                p.line(x-ux*length,y-uy*length,x-ux*length*0.35,y-uy*length*0.35,PAL.scale_color(col,0.55),a)
                p.line(x-ux*length*0.4,y-uy*length*0.4,x,y,col,a)
                p.glow(x,y,2.5+size,col,0.4*k)
            STREAK:
                var length: float=clampf(sp/30.0,1.0,7.0)
                var d: float=length
                while d>=0.0:
                    p.dot(x-ux*d,y-uy*d,WHITE if d<1.0 else (col if d<length*0.5 else PAL.scale_color(col,0.6)),1.0 if d<length*0.5 else 1.2-d/length)
                    d-=0.5
                p.glow(x,y,4.0,col,0.4)
            FLAKE:
                var a: float=minf(1.0,k*3.0)
                p.dot(x,y,col,a)
                if size>1.3:
                    for v in CROSS:
                        p.dot(x+v[0],y+v[1],PAL.scale_color(col,0.8),a*0.8)
            GRIT:
                if k>0.25 or k*4.0>0.5:
                    p.px(x,y,col)
                    if size>=2.0:
                        p.px(x+1,y,col)
                        p.px(x,y+1,PAL.scale_color(col,0.8))
                        p.px(x+1,y+1,PAL.scale_color(col,0.7))
            EMBER:
                var c: int=sparks[0] if k>0.6 else (sparks[1] if k>0.3 else sparks[2])
                if k<0.25 and sin(t*40.0+q["seed"])<0.0:
                    continue
                p.px(x,y,c)
                if size>1.5:
                    p.px(x,y+1,sparks[-1])
                p.glow(x,y,3.0+size,c,0.35*k)
            STAR:
                var tw: float=0.6+0.4*sin(t*(8.0+fmod(q["seed"],5.0))+q["seed"])
                if size<1.0:
                    if tw*k>0.25:
                        p.px(x,y,WHITE if tw>0.8 else col)
                    p.glow(x,y,3.0,col,0.4*k*tw)
                else:
                    sparkle(p,x,y,size*tw*minf(1.0,k*3.0),col,PAL.scale_color(col,0.75),0.5*k*tw)
