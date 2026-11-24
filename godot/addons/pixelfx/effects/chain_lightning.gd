extends RefCounted
## Direct port of original lightning/chain-lightning.js. MIT Patch/Hugo Duprez.
## Original authored effect only; actor choreography/rig is separate.
const R=preload("res://addons/pixelfx/native/rng.gd")
const M=preload("res://addons/pixelfx/native/math.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const P=preload("res://addons/pixelfx/native/particles.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const LIGHTS=preload("res://addons/pixelfx/native/lights.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const HAND=[10,-16]
const HOPS=[[58,-22],[104,-30],[150,-19]]
const WIND: float=.12
const LEAP: float=.05
const GAP: float=.075
const HOLD: float=.78
const BREAK: float=.16
const WHITE: int=0xffffffff
const META={"duration":1.8,"loop":false,"actor":2,"options":{"palette":L.VOLT,"sparks":["#ffffff","#c8f8ff","#7ff3ff","#1ab8e6"],"seed":3}}
const SIZE:=Vector2i(248,104)
const PIVOT:=Vector2i(40,82)
var lightning=L.new()
var batch=BATCH.new()
var rng
var ps
var hot
var lights=LIGHTS.new()
var c: Array
var ash: int=PAL.from_hex("#5b5566")
var seed_value: int
var t: float=0.0
var pts: Array=[HAND]+HOPS
var hit: Array=[false,false,false]
var popped: Array=[false,false,false]
var ground: Array=[]

func _init(o: Dictionary={}) -> void:
    seed_value=o.get("seed",3)
    c=PAL.fit(o.get("palette",L.VOLT),8)
    rng=R.new(seed_value)
    ps=P.new(seed_value,_floor,o.get("sparks",META["options"]["sparks"]))
    hot=P.new(seed_value,_floor)
    ps.rng=rng
    hot.rng=rng
    for q in HOPS:
        ground.append(q[0]+rng.between(-5,5))

func _floor(_x: float) -> float:
    return 0.0

func enable_acceleration(enabled: bool=true) -> bool:
    var a: bool=lightning.enable_acceleration(enabled)
    var b: bool=batch.enable_acceleration(enabled)
    return a and b

static func on(i: int) -> float:
    return WIND+i*GAP+LEAP

static func off(i: int) -> float:
    return HOLD+i*.05

static func level(i: int,t0: float) -> float:
    var a: float=t0-on(i)
    if a<0:
        return 0.0
    var hum: float=1.0
    if a<.1:
        var j: int=int(floor(a*30))
        hum=[1.0,.55,1.0][j] if j<3 else 1.0
    else:
        hum=.78+.22*sin(t0*61+i)*sin(t0*23+i*2)
    var b: float=t0-off(i)
    return hum if b<0 else (hum*(1-b/BREAK)*(.5 if int(floor(b*60))%3==1 else 1.0) if b<BREAK else 0.0)

func shape(i: int,f: int,salt: int=0) -> Array:
    var r=M.rng_for([seed_value,31+salt,i,f])
    var a: Array=pts[i]
    var b: Array=pts[i+1]
    var length: float=M.distance(a[0],a[1],b[0],b[1])
    return L.bowed(r,a[0],a[1],b[0],b[1],-length*r.between(.05,.15),.2,.08)

func update(dt: float) -> void:
    t+=dt
    if t<WIND and rng.chance(70*dt):
        var a: float=rng.between(0,TAU)
        var d: float=rng.between(10,24)
        var life: float=rng.between(.06,.1)
        var v: float=d*3/(exp(3*life)-1)
        ps.spawn(P.STREAK,HAND[0]+cos(a)*d,HAND[1]+sin(a)*d,-cos(a)*v,-sin(a)*v,life,c[6] if rng.chance(.5) else c[5])
    for i in range(3):
        var x: float=HOPS[i][0]
        var y: float=HOPS[i][1]
        if not hit[i] and t>=on(i):
            hit[i]=true
            var dir: float=atan2(y-pts[i][1],x-pts[i][0])
            lights.add(x,y,56,c[4],.85,.22)
            lights.add(x,y,16,WHITE,.7,.08)
            if i==0:
                lights.add(HAND[0],HAND[1],40,c[4],.6,.15)
            for j in range(18):
                var a: float=dir+rng.between(-1.1,1.1) if rng.chance(.6) else rng.between(0,TAU)
                var sp: float=rng.between(70,230)
                ps.spawn(P.SPARK,x,y,cos(a)*sp,sin(a)*sp-40,rng.between(.15,.4))
            for j in range(5):
                hot.spawn(P.SPARK,x+rng.between(-2,2),y+2,rng.between(-50,50),rng.between(-60,20),rng.between(.5,.9))
            ps.spawn(P.STAR,x+rng.between(-4,4),y-rng.between(3,7),0,-6,rng.between(.25,.4),c[6],rng.between(1.5,2.5))
            for j in range(2):
                ps.spawn(P.SMOKE,x+rng.between(-4,4),y+rng.between(-2,3),rng.between(-6,6),-rng.between(8,16),rng.between(.7,1),PAL.mix(ash,c[2],.35),rng.between(2,3.5),rng.between(.1,.25))
        if hit[i] and t<off(i):
            if rng.chance(9*dt):
                var u: float=rng.next()
                ps.spawn(P.SPARK,lerpf(pts[i][0],x,u),lerpf(pts[i][1],y,u)-2,rng.between(-60,60),rng.between(-90,20),rng.between(.1,.25))
            if rng.chance(7*dt):
                ps.spawn(P.SPARK,ground[i],-1,rng.between(-70,70),-rng.between(40,140),rng.between(.12,.3))
            if rng.chance(2*dt):
                hot.spawn(P.SPARK,x+rng.between(-3,3),y+3,rng.between(-30,30),rng.between(-30,10),rng.between(.5,.8))
        if not popped[i] and t>=off(i)+BREAK:
            popped[i]=true
            for j in range(7):
                var a: float=rng.between(0,TAU)
                var sp: float=rng.between(40,140)
                ps.spawn(P.SPARK,x,y,cos(a)*sp,sin(a)*sp-30,rng.between(.12,.3))
            ps.spawn(P.SMOKE,x,y,rng.between(-4,4),-rng.between(10,16),rng.between(.55,.7),PAL.mix(ash,c[2],.35),rng.between(2.5,3.5))
            lights.add(x,y,30,c[4],.5,.12)
    ps.update(dt)
    hot.update(dt)
    lights.update(dt)

func draw_back(p,_tt: float) -> void:
    var d=batch.begin(p)
    for i in range(3):
        var a: float=t-on(i)
        if a<0:
            continue
        var heat: float=minf(1,a/.2)*pow(clampf(1-(t-off(i))/.7,0,1),1.3)*.9
        L.scorch(d,ground[i],0,7,heat,1-M.smooth(1.35,1.75,t))
    ps.draw(d,"back")
    hot.draw(d,"back")
    batch.finish()

func draw(p,_tt: float) -> void:
    var f: int=int(floor(t*30+1e-4))
    var f2: int=f>>1
    var kh: float=t/WIND if t<WIND else level(0,t)
    if kh>.02:
        var r: float=(1.2+1.6*kh+sin(t*53)*.4)*minf(1,kh*1.5)
        var d=batch.begin(p)
        d.circle(HAND[0],HAND[1],r+1.2,c[4])
        d.circle(HAND[0],HAND[1],r,c[6])
        d.circle(HAND[0],HAND[1],r*.5,WHITE)
        d.glow(HAND[0],HAND[1],18,c[4],.6*kh)
        batch.finish()
        if t>WIND*.5:
            var r2=M.rng_for([seed_value,5,f])
            var a: float=r2.between(0,TAU)
            var dist: float=r2.between(4,8)
            lightning.crackle(p,L.zigzag(r2,HAND[0],HAND[1],HAND[0]+cos(a)*dist,HAND[1]+sin(a)*dist,.4,.3),.6*kh,c,.3)
    for i in range(3):
        var x: float=HOPS[i][0]
        var y: float=HOPS[i][1]
        var t0: float=WIND+i*GAP
        if t>=t0 and t<on(i):
            var u: float=M.easing("outQuad",(t-t0)/LEAP)
            var b: Array=shape(i,-1)
            lightning.stroke(p,[b[0]],1,c,.75,{"upTo":u})
            var tp: Array=b[0]["pts"]
            var h: Array=tp[mini(tp.size()-1,int(floor(u*(tp.size()-1))))]
            var d=batch.begin(p)
            d.circle(h[0],h[1],2,WHITE)
            d.glow(h[0],h[1],16,c[5],.7)
            batch.finish()
        var k: float=level(i,t)
        if k>0:
            lightning.stroke(p,shape(i,f2),k,c,.75)
        elif t>=off(i)+BREAK and t<off(i)+BREAK+.35:
            var g: float=1-(t-off(i)-BREAK)/.35
            var b: Array=shape(i,int(floor((off(i)+BREAK)*15)))
            var d=batch.begin(p)
            L.trace(d,b[0]["pts"],c[4] if g>.5 else c[2],g*.9)
            batch.finish()
        var a: float=t-on(i)
        var d=batch.begin(p)
        if a>=0 and a<.09:
            var q: float=a/.09
            d.circle(x,y,6*(1-q)+1.5,c[5])
            d.circle(x,y,5*(1-q),WHITE)
            P.sparkle(d,x,y,floor(10*(1-q)+.5),c[6],c[4],.6)
        if k>.05:
            var r: float=(2.6+sin(t*47+i)*.7)*k
            d.circle(x,y,r+1.5,c[2])
            d.circle(x,y,r+.7,c[5])
            d.circle(x,y,r*.6,WHITE)
            d.glow(x,y,26,c[4],.6*k)
            d.glow(x,y,8,c[6],.5*k)
        batch.finish()
        if k>.05:
            var r2=M.rng_for([seed_value,11,i,f])
            for j in range(2 if t-on(i)<.12 else 1):
                var a0: float=r2.between(0,TAU)
                var a1: float=a0+r2.sign()*r2.between(.5,1)
                var d0: float=r2.between(4,6)
                var d1: float=r2.between(5,8)
                lightning.crackle(p,L.zigzag(r2,x+cos(a0)*d0,y+sin(a0)*d0,x+cos(a1)*d1,y+sin(a1)*d1,.35,0),r2.between(.45,.7)*k,c,.25)
            if r2.next()<.3*k:
                var gx: float=ground[i]+r2.between(-3,3)
                lightning.crackle(p,L.zigzag(r2,x+r2.between(-2,2),y+3,gx,-.5,.3,.35),.75*k,c,.35)
                d=batch.begin(p)
                d.glow(gx,-1,12,c[5],.5*k)
                d.px(gx,-1,WHITE)
                batch.finish()
    var d=batch.begin(p)
    ps.draw(d,"front")
    hot.draw(d,"front")
    lights.draw(d)
    batch.finish()
