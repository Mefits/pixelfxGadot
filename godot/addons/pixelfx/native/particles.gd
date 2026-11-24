extends RefCounted
## Direct reference port of the electrical/hard particle kinds from src/core/sim.js.
## Original MIT: Patch, Hugo Duprez, 2026. Adapted upstream from Sprite Fusion.
## Includes all 12 upstream kinds with an explicit host capacity budget.
const PAL = preload("res://addons/pixelfx/native/palette.gd")
const RNG = preload("res://addons/pixelfx/native/rng.gd")
const GRAVITY: float = 950.0
const SPARK: int = 0
const MOTE: int = 1
const STREAK: int = 2
const FLAKE: int = 3
const VAPOUR: int = 4
const DUST: int = 5
const STAR: int = 6
const EMBER: int = 7
const SMOKE: int = 8
const FIRE: int = 9
const BRAND: int = 10
const GRIT: int = 11
const SMOKES: int = 1
const BIG: int = 2
const SOFT = [VAPOUR,DUST,SMOKE]
const FIRE_HEX = ["#ffffff","#fff3a6","#ffe26b","#ffc23d","#ff8a2a","#f2561d","#c9281f","#8a1f17","#4a1712"]
const SMOKE_HEX = ["#7b6f72","#5d5660","#433d48","#2b2630","#1a171e"]
const HOT_HEX = ["#fff3a6","#ffe26b","#ff8a2a","#f2561d"]
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
var haze: int=0
var on_land: Callable
var fire_ramp: Array
var smoke_ramp: Array
var hot: Array

func _init(seed_value: int=1, ground_fn: Callable=Callable(), ramp: Array=[]) -> void:
    rng=RNG.new(seed_value)
    ground=ground_fn
    var source: Array = ramp if not ramp.is_empty() else ["#fff3a6","#ffe26b","#ff8a2a","#f2561d"]
    sparks=PAL.fit(source,source.size())
    fire_ramp=PAL.fit(FIRE_HEX,FIRE_HEX.size())
    smoke_ramp=PAL.fit(SMOKE_HEX,SMOKE_HEX.size())
    hot=PAL.fit(HOT_HEX,HOT_HEX.size())

func floor_at(x: float) -> float:
    return float(ground.call(x)) if ground.is_valid() else INF

func spawn(kind: int,x: float,y: float,vx: float,vy: float,life: float,col: int=WHITE,size: float=1.0,delay: float=0.0,flag: int=0) -> bool:
    if kind<0 or kind>11:
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
            if int(p["k"])==FIRE and (int(p["flag"])&SMOKES)!=0:
                var big: bool=(int(p["flag"])&BIG)!=0
                spawn(SMOKE,p["x"],p["y"],p["vx"]*0.6,p["vy"]*0.6-6.0,rng.between(1.3,2.3) if big else rng.between(0.8,1.4),0,p["size"]*(0.85 if big else 0.7),0.0,BIG if big else 0)
            list.remove_at(i)
            continue
        match int(p["k"]):
            FIRE:
                p["vy"]-=95.0*dt
                p["vx"]+=sin(t*17.0+p["seed"])*30.0*dt
                p["vx"]-=p["vx"]*5.0*dt
                p["vy"]-=p["vy"]*3.2*dt
            BRAND:
                p["vy"]+=GRAVITY*0.8*dt
                p["vx"]-=p["vx"]*0.9*dt
                if rng.chance(0.9*minf(1.0,dt*60.0)):
                    spawn(FIRE,p["x"],p["y"],p["vx"]*0.1+rng.between(-7.0,7.0),p["vy"]*0.1-10.0,rng.between(0.16,0.32),0,rng.between(0.9,1.7)*(0.5+p["life"]/p["max"]*0.6),0.0,SMOKES if rng.chance(0.4) else 0)
                var g: float=floor_at(p["x"])
                var ny: float=p["y"]+p["vy"]*dt
                p["x"]+=p["vx"]*dt
                if p["vy"]>0.0 and p["y"]<=g and ny>=g:
                    if on_land.is_valid():
                        on_land.call(p["x"],g)
                    list.remove_at(i)
                else:
                    p["y"]=ny
                continue
            SMOKE:
                p["vy"]-=(23.0 if (int(p["flag"])&BIG)!=0 else 16.0)*dt
                p["vx"]+=sin(t*1.3+p["seed"])*8.0*dt
                p["vx"]-=p["vx"]*1.6*dt
                p["vy"]-=p["vy"]*1.2*dt
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
                var drag: float=4.0 if int(p["k"]) in SOFT else 1.6
                p["vx"]-=p["vx"]*drag*dt
                p["vy"]-=p["vy"]*drag*dt+5.0*dt
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
        var back: bool=int(q["k"]) in SOFT or (int(q["flag"])&BACK)!=0
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
            VAPOUR:
                var r: float=size*(0.6+(1.0-k)*0.9)
                p.disc(x,y,r,col,pow(k,1.3)*0.45)
                if haze!=0:
                    p.glow(x,y,r*1.8,haze,0.16*k)
            DUST:
                p.disc(x,y,size*(0.6+(1.0-k)*0.9),col,pow(k,1.3)*0.7)
            SMOKE:
                var age: float=1.0-k
                var big: bool=(int(q["flag"])&BIG)!=0
                var r: float=size*(0.65+minf(1.0,age*2.5)*0.45+age*(0.5 if big else 0.4))
                var a: float=minf(1.0,age*12.0)*minf(1.0,k*2.4)*(0.7 if big else 0.58)
                var c: int=PAL.mix(col,PAL.at(smoke_ramp,age),age) if col!=0 else PAL.at(smoke_ramp,age*1.05)
                p.disc(x,y,r,c,a*0.45)
                p.disc(x+r*0.05,y+r*0.06,r*0.74,c,a*0.62)
                if age<0.5:
                    p.disc(x-r*0.22,y-r*0.3,r*0.5,PAL.mix(c,WHITE,0.12),a*0.4*(1.0-age*2.0))
            FIRE:
                var age: float=1.0-k
                var heat: float=minf(0.999,pow(age,0.62)+fmod(q["seed"],1.0)*0.1)
                var n: int=fire_ramp.size()
                var idx: int=mini(n-2,int(floor(heat*(n-1))))
                var r: float=size*(0.55+0.45*minf(1.0,age*7.0))*(1.0-age*0.55)
                var c: int=fire_ramp[idx]
                if idx>=n-2:
                    p.disc(x,y,r,c,minf(1.0,k*3.0)*0.85)
                else:
                    p.circle(x,y,r,fire_ramp[mini(n-1,idx+2)])
                    p.circle(x-r*0.16,y-r*0.22,r*0.78,c)
                    if r>1.6:
                        p.circle(x,y-r*0.9,r*0.42,c)
                    if idx<=3 and r>1.8:
                        p.circle(x-r*0.28,y-r*0.34,r*0.36,fire_ramp[maxi(0,idx-1)])
                    if idx<6:
                        p.glow(x,y,r*2.4+2.0,c,0.18*k)
            BRAND:
                p.circle(x,y,1.6,hot[3])
                p.px(x,y,hot[0] if sin(t*40.0+q["seed"])>0.0 else hot[1])
                p.px(x+1.0,y,hot[1])
                p.glow(x,y,7.0,hot[2],0.45)
            STAR:
                var tw: float=0.6+0.4*sin(t*(8.0+fmod(q["seed"],5.0))+q["seed"])
                if size<1.0:
                    if tw*k>0.25:
                        p.px(x,y,WHITE if tw>0.8 else col)
                    p.glow(x,y,3.0,col,0.4*k*tw)
                else:
                    sparkle(p,x,y,size*tw*minf(1.0,k*3.0),col,PAL.scale_color(col,0.75),0.5*k*tw)
