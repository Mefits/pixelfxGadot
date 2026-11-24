extends RefCounted
## Original toolkit composition, NOT a port of an existing PixelFX effect.
## Art direction: contracting broken orbit -> momentary dark slit -> asymmetric
## plasma rupture -> cooling ballistic debris. Uses verified shared primitives.
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const MOTION=preload("res://addons/pixelfx/native/motion.gd")
const PS=preload("res://addons/pixelfx/native/particles.gd")
const SIZE:=Vector2i(192,128)
const PIVOT:=Vector2i(96,64)
const DURATION: float=1.7
const FPS: int=30
const LOOP: bool=false
const RELEASE: float=0.56
const WHITE: int=0xffffffff
const PALETTES=[
    ["#180e2d","#39205c","#67309c","#a044c9","#d761ed","#f2a3ff","#ffe2fd","#ffffff"],
    ["#09232b","#114b62","#16798c","#30b4b9","#57e5d9","#9df9ee","#ddfff6","#ffffff"],
    ["#2b131b","#632136","#aa3a3d","#e16a38","#ffad48","#ffd183","#fff0c2","#ffffff"]
]
var lightning=L.new()
var batch=BATCH.new()
var seed_value: int
var preset: int
var c: Array
var motes: Array=[]
var fragments: Array=[]
var smoke: Array=[]

func _init(seed: int=121,preset_index: int=0) -> void:
    seed_value=seed
    preset=clampi(preset_index,0,2)
    c=PAL.fit(PALETTES[preset],8)
    for i in range(42):
        var r=RNG.new(RNG.hash32([seed,10,i]))
        motes.append([r.between(0,TAU),r.between(24,67),r.between(0.0,0.30),r.between(0.12,0.24),r.between(0.7,1.5)])
    for i in range(88):
        var r=RNG.new(RNG.hash32([seed,20,i]))
        var a: float=r.between(0,TAU)
        var sp: float=r.between(30,195)
        # Bias toward two opposed lobes; preset 1 is broad, preset 2 sharply diagonal.
        var stretch: float=[1.0,0.78,1.1][preset]
        var vx: float=cos(a)*sp*stretch
        var vy: float=sin(a)*sp*0.57
        if preset==2:
            vy+=vx*0.28
        fragments.append([vx,vy,r.between(0.26,0.94),r.between(0,0.09),r.between(0.6,2.0),r.between(0,TAU),r.between(-8,8)])
    for i in range(12):
        var r=RNG.new(RNG.hash32([seed,30,i]))
        smoke.append([r.between(-37,37),r.between(-19,19),r.between(6,13),r.between(0.38,0.83),r.between(0.02,0.15)])

func enable_acceleration(enabled: bool=true) -> bool:
    var a: bool=lightning.enable_acceleration(enabled)
    var b: bool=batch.enable_acceleration(enabled)
    return a and b

static func _ease(x: float) -> float:
    var u: float=clampf(x,0,1)
    return u*u*(3.0-2.0*u)

func _orbit(p,t: float,rad: float,power: float,segments: int=3) -> void:
    # Broken tilted rings, with dark rim and bright leading edge.
    for j in range(segments):
        var start: float=t*(2.6 if preset!=1 else -2.2)+j*TAU/segments
        for i in range(18):
            var a: float=start+i*0.077
            var b: float=a+0.077
            var x: float=cos(a)*rad
            var y: float=sin(a)*rad*0.54+cos(a)*rad*0.19
            var xx: float=cos(b)*rad
            var yy: float=sin(b)*rad*0.54+cos(b)*rad*0.19
            var k: float=float(i)/17.0
            p.line(x,y+1,xx,yy+1,c[2],power)
            p.line(x,y,xx,yy,c[6] if k>0.79 else (c[4] if k>0.3 else c[3]),power)
            if i%5==0:
                p.glow(x,y,7,c[4],power*0.18)

func draw(p,t: float) -> void:
    if t<0.0 or t>=DURATION:
        return
    var d=batch.begin(p)
    if t<RELEASE:
        var u: float=_ease(t/RELEASE)
        var rad: float=lerpf(53,5,u)
        var k: float=minf(1.0,t*12.0)
        _orbit(d,t,rad,k,4 if preset==1 else 3)
        for q in motes:
            var age: float=t-q[2]
            if age<0.0 or age>q[3]+0.12:
                continue
            var v: float=clampf(age/(q[3]+0.12),0,1)
            var a: float=q[0]+v*1.35
            var rr: float=q[1]*(1-v*v)+3.0
            var x: float=cos(a)*rr
            var y: float=sin(a)*rr*0.64
            var tail: float=rr+4.0+v*9.0
            d.line(cos(a-0.13)*tail,sin(a-0.13)*tail*0.64,x,y,c[4],k)
            d.px(x,y,c[6])
            d.glow(x,y,3,c[4],0.27*k)
        d.glow(0,0,19+u*18,c[4],0.42*k)
        d.circle(0,0,2.0+u*5,c[2])
        d.circle(0,0,1.0+u*3.2,c[5])
        d.circle(0,0,0.7+u*1.1,WHITE)
        batch.finish()
        if t>0.13:
            var paths: Array=[]
            for j in range(3):
                var r=RNG.new(RNG.hash32([seed_value,40,j,int(floor(t*15))]))
                var a: float=j*TAU/3.0+t*3.0
                paths.append_array(L.zigzag(r,cos(a)*rad,sin(a)*rad*0.54,cos(a+0.38)*rad*0.38,sin(a+0.38)*rad*0.26,0.27,0.35))
            lightning.crackle(p,paths,0.55+u*0.35,c,0.35)
        return
    var age: float=t-RELEASE
    # Translucent smoke painted behind the hot material, not baked into a sprite.
    for s in smoke:
        var a: float=age-s[4]
        if a<0 or a>=s[3]:
            continue
        var u: float=a/s[3]
        var x: float=s[0]*(0.2+u)
        var y: float=s[1]*(0.3+u)-12*u
        var r: float=s[2]*(0.5+u*0.8)
        d.disc(x,y,r,c[1],sin(u*PI)*0.34)
        d.disc(x-2,y-2,r*0.68,c[2],sin(u*PI)*0.14)
    if age<0.33:
        var u: float=age/0.33
        var rad: float=7.0+65.0*(1.0-pow(1.0-u,3))
        _orbit(d,-age*1.8,rad,(1.0-u)*0.86,4)
        if age<0.12:
            var k: float=1.0-age/0.12
            d.glow(0,0,54,c[4],0.85*k)
            d.circle(0,0,11*k+1,c[3])
            d.circle(0,0,7*k+1,c[6])
            d.circle(0,0,4*k,WHITE)
            PS.sparkle(d,0,0,13*k,c[6],c[4],0.9*k)
    batch.finish()
    if age<0.27:
        var paths: Array=[]
        for j in range(5):
            var r=RNG.new(RNG.hash32([seed_value,50,j,int(floor(age*24))]))
            var a: float=j*TAU/5.0+r.between(-0.23,0.23)
            var dist: float=r.between(24,68)*(0.5+0.5*minf(1.0,age*9))
            paths.append_array(L.zigzag(r,cos(a)*3,sin(a)*3,cos(a)*dist,sin(a)*dist*0.63,0.28,0.6))
        lightning.stroke(p,paths,1.0-age/0.27,c,0.65,{"hero":age<0.035,"light":0.5})
    d=batch.begin(p)
    for q in fragments:
        var a: float=age-q[3]
        if a<0.0 or a>=q[2]:
            continue
        var k: float=1.0-a/q[2]
        var pos: Array=MOTION.fly(0,0,q[0],q[1],a,90,3.2)
        var old: Array=MOTION.fly(0,0,q[0],q[1],maxf(0.0,a-0.035),90,3.2)
        var x: float=pos[0]
        var y: float=pos[1]
        d.line(old[0],old[1],x,y,c[3] if k<0.45 else c[5],minf(1.0,k*2))
        d.dot(x,y,c[6] if k>0.55 else c[4],minf(1.0,k*3))
        if q[4]>1.4:
            var spin: float=q[5]+q[6]*a
            d.line(x-cos(spin)*q[4],y-sin(spin)*q[4],x+cos(spin)*q[4],y+sin(spin)*q[4],c[5] if k>0.4 else c[2],k)
        if k>0.25:
            d.glow(x,y,2.8+q[4],c[4],0.25*k)
    batch.finish()
