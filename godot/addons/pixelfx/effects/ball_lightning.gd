extends RefCounted
## Direct port of original src/fx/lightning/ball-lightning.js, MIT Patch/Hugo Duprez.
## Original loop, wake, corona, grounding and spark trajectories. No actor dependency.
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const WHITE: int=0xffffffff
const DURATION: float=4.0
const FPS: int=30
const SIZE:=Vector2i(136,104)
const PIVOT:=Vector2i(68,92)
const ZAP: int=62
var seed_value: int=9
var colors: Array
var sparks: Array
var lightning=L.new()
var batch=BATCH.new()

func _init(seed: int=9,palette: Array=[],spark_palette: Array=[]) -> void:
    seed_value=seed
    colors=PAL.fit(L.VOLT if palette.is_empty() else palette,8)
    sparks=PAL.fit(["#ffffff","#c8f8ff","#7ff3ff","#1ab8e6"] if spark_palette.is_empty() else spark_palette,4)

func enable_acceleration(enabled: bool=true) -> bool:
    var bolts: bool=lightning.enable_acceleration(enabled)
    var primitives: bool=batch.enable_acceleration(enabled)
    return bolts and primitives

static func at(t: float) -> Array:
    var a: float=(t/DURATION)*TAU
    return [38.0*sin(a)+9.0*sin(2.0*a+1.0),-42.0+13.0*sin(2.0*a+0.4)+6.0*sin(3.0*a+0.5)]

static func _rng(values: Array):
    return RNG.new(RNG.hash32(values))

static func _wrap(x: float,m: float) -> float:
    return fmod(fmod(x,m)+m,m)

static func _flight(x: float,y: float,vx: float,vy: float,age: float) -> Array:
    const DT: float=1.0/120.0
    var s: float=0.0
    while s<age:
        var h: float=minf(DT,age-s)
        vy+=950.0*0.45*h
        vx-=vx*2.2*h
        vy-=vy*2.2*h
        var ny: float=y+vy*h
        x+=vx*h
        if vy>0.0 and y<=0.0 and ny>=0.0:
            vy=-vy*0.45
            vx*=0.7
            y=-0.25
        else:
            y=ny
        s+=DT
    return [x,y,vx,vy]

func _spark(p,x: float,y: float,vx: float,vy: float,k: float) -> void:
    var sp: float=sqrt(vx*vx+vy*vy)
    if sp==0.0:
        sp=1.0
    var ux: float=vx/sp
    var uy: float=vy/sp
    var head: int=sparks[0] if k>0.6 else (sparks[1] if k>0.3 else sparks[2])
    var length: float=minf(9.0,1.0+sp*0.022)
    p.line(x-ux*length,y-uy*length,x-ux*length*0.4,y-uy*length*0.4,head if k>0.5 else sparks[-1])
    p.line(x-ux*length*0.45,y-uy*length*0.45,x,y,head)
    p.glow(x,y,3.0,head,0.45*k)

func draw(p,t: float) -> void:
    t=_wrap(t,DURATION) if t<0.0 or t>=DURATION else t
    var c: Array=colors
    var f: int=int(floor(t*FPS+0.000001))%120
    var r=_rng([seed_value,1,f])
    var pos: Array=at(t)
    var x: float=pos[0]
    var y: float=pos[1]
    var d=batch.begin(p)
    d.glow(x,-2,30,c[3],0.12+0.3*clampf((y+60.0)/40.0,0.0,1.0))
    for i in range(14,0,-1):
        var w: Array=at(t-i*0.034)
        var u: float=float(i)/14.0
        var rr: float=3.0*(1.0-u)+0.3
        if u>0.6 and (i+f)%2!=0:
            continue
        d.circle(w[0],w[1],rr+0.8,c[3] if u<0.35 else c[2])
        d.circle(w[0],w[1],rr,c[6] if u<0.35 else (c[5] if u<0.7 else c[4]))
        d.glow(w[0],w[1],7.0*(1.0-u)+3.0,c[4],0.25*(1.0-u))
    # Original cycle helper: seeded birth phase and per-particle lifetime.
    for i in range(40):
        var g=_rng([seed_value+5,i,911])
        var born: float=g.next()*DURATION
        var life: float=g.between(0.5,1.0)
        var age: float=_wrap(t-born,DURATION)
        while age<life:
            var q=_rng([seed_value+5,i])
            var b: Array=at(t-age)
            var k: float=1.0-age/life
            var a: float=q.between(0,TAU)
            var sp: float=q.between(4,14)
            var mx: float=b[0]+cos(a)*sp*age+q.between(-3,3)
            var my: float=b[1]+sin(a)*sp*age+6.0*age+q.between(-3,3)
            if k>0.25 or f%2!=0:
                d.px(mx,my,c[6] if k>0.6 else (c[4] if k>0.3 else c[3]))
            d.glow(mx,my,3,c[4],0.3*k)
            age+=DURATION
    var r0: float=5.2+0.6*sin(t*9.0)+0.4*r.between(-1,1)
    d.circle(x,y,r0+1.3,c[2])
    d.circle(x,y,r0,c[4])
    d.circle(x-0.4,y-0.4,r0*0.72,c[5])
    for i in range(3):
        var a: float=t*(5.0+i*2.3)+i*2.1
        var dist: float=r0*0.6
        d.circle(x+cos(a)*dist,y+sin(a)*dist*0.8,1.2,c[6] if i!=0 else WHITE)
    d.circle(x-0.6,y-0.6,r0*0.32,WHITE)
    for i in range(8):
        if r.next()<0.35:
            continue
        var a: float=float(i)/8.0*TAU+t*2.0+r.between(-0.2,0.2)
        var length: float=r.between(1.5,4)
        d.line(x+cos(a)*(r0+1.0),y+sin(a)*(r0+1.0),x+cos(a)*(r0+1.0+length),y+sin(a)*(r0+1.0+length),c[5] if i%2!=0 else c[4])
    d.glow(x,y,30,c[4],0.3)
    d.glow(x,y,9,c[6],0.1)
    batch.finish()
    var arc: int=0
    # Preserve original JS loop: RNG is evaluated again at each condition.
    while arc<2+(1 if r.next()<0.4 else 0):
        var a: float=r.between(0,TAU)
        var length: float=r.between(5,11)
        var x0: float=x+cos(a)*(r0+1.0)
        var y0: float=y+sin(a)*(r0+1.0)
        var b: float=a+r.between(-0.7,0.7)
        var paths: Array=L.zigzag(r,x0,y0,x0+cos(b)*length,y0+sin(b)*length,0.4,0.3)
        lightning.crackle(p,paths,r.between(0.4,0.7),c,0.25)
        arc+=1
    var za: int=f-ZAP
    var ground_pos: Array=at(float(ZAP)/FPS)
    var gx: float=ground_pos[0]+_rng([seed_value,3]).between(-10,10)
    if za>=0 and za<4:
        var k: float=[1.0,0.6,0.9,0.4][za]
        lightning.stroke(p,L.zigzag(_rng([seed_value,4,f]),x,y+r0,gx,0,0.28,0.4),k,c,0.7,{"hero":za==0})
    d=batch.begin(p)
    if za>=0 and za<4:
        var k: float=[1.0,0.6,0.9,0.4][za]
        d.circle(gx,-1,2.5*k+1.0,c[5])
        d.px(gx,-1,WHITE)
        d.glow(gx,-4,34,c[4],0.6*k)
    var sa: float=_wrap(t-float(ZAP)/FPS,DURATION)
    for j in range(14):
        var q=_rng([seed_value,7,j])
        var life: float=q.between(0.25,0.55)
        if sa>=life:
            continue
        var a: float=-PI/2.0+q.between(-1.3,1.3)
        var sp: float=q.between(50,170)
        var fly: Array=_flight(gx,-1,cos(a)*sp,sin(a)*sp,sa)
        _spark(d,fly[0],fly[1],fly[2],fly[3],1.0-sa/life)
    batch.finish()
