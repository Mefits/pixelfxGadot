extends RefCounted
## PixelFX core/math.js, deterministic noise and timing. MIT Patch/Hugo Duprez.
const RNG=preload("res://addons/pixelfx/native/rng.gd")
static func rand_hash(ns: Array) -> float:
    return float(RNG.hash32(ns))/4294967296.0

static func rng_for(ns: Array):
    return RNG.new(RNG.hash32(ns))

static func wrap_period(x: float,m: float) -> float:
    return fmod(fmod(x,m)+m,m)

static func fract(x: float) -> float:
    return x-floor(x)

static func inv_lerp(a: float,b: float,x: float) -> float:
    return 0.0 if a==b else (x-a)/(b-a)

static func remap_value(x: float,a0: float,a1: float,b0: float,b1: float) -> float:
    return lerpf(b0,b1,inv_lerp(a0,a1,x))

static func seg(t: float,t0: float,t1: float) -> float:
    return clampf((t-t0)/(t1-t0),0,1)

static func smooth(e0: float,e1: float,x: float) -> float:
    var t: float=seg(x,e0,e1)
    return t*t*(3-2*t)

static func bump(t: float,t0: float,t1: float) -> float:
    return 0.0 if t<=t0 or t>=t1 else sin(PI*seg(t,t0,t1))

static func ping_pong(x: float) -> float:
    return 1.0-absf(wrap_period(x,2)-1)

static func distance(x0: float,y0: float,x1: float,y1: float) -> float:
    return sqrt(pow(x1-x0,2)+pow(y1-y0,2))

static func angle_to(x0: float,y0: float,x1: float,y1: float) -> float:
    return atan2(y1-y0,x1-x0)

static func easing(name: String,t: float,s: float=1.70158) -> float:
    match name:
        "inQuad": return t*t
        "outQuad": return 1-(1-t)*(1-t)
        "inOutQuad": return 2*t*t if t<.5 else 1-pow(-2*t+2,2)/2
        "inCubic": return t*t*t
        "outCubic": return 1-pow(1-t,3)
        "inOutCubic": return 4*t*t*t if t<.5 else 1-pow(-2*t+2,3)/2
        "inQuart": return t*t*t*t
        "outQuart": return 1-pow(1-t,4)
        "inExpo": return 0.0 if t<=0 else pow(2,10*t-10)
        "outExpo": return 1.0 if t>=1 else 1-pow(2,-10*t)
        "inSine": return 1-cos(t*PI/2)
        "outSine": return sin(t*PI/2)
        "inOutSine": return -(cos(PI*t)-1)/2
        "inBack": return 0.0 if t<=0 else (1.0 if t>=1 else (s+1)*t*t*t-s*t*t)
        "outBack": return 0.0 if t<=0 else (1.0 if t>=1 else 1+(s+1)*pow(t-1,3)+s*pow(t-1,2))
        "outElastic": return 0.0 if t<=0 else (1.0 if t>=1 else pow(2,-10*t)*sin((t*10-.75)*(TAU/3))+1)
        "outBounce":
            if t<1/2.75: return 7.5625*t*t
            if t<2/2.75:
                t-=1.5/2.75
                return 7.5625*t*t+.75
            if t<2.5/2.75:
                t-=2.25/2.75
                return 7.5625*t*t+.9375
            t-=2.625/2.75
            return 7.5625*t*t+.984375
    return t

static func noise(x: float,seed: int=0) -> float:
    var i: int=int(floor(x))
    var f: float=x-i
    var u: float=f*f*(3-2*f)
    return lerpf(rand_hash([i,seed]),rand_hash([i+1,seed]),u)*2-1

static func noise2(x: float,y: float,seed: int=0) -> float:
    return tile_noise(x,y,0,0,seed)

static func tile_noise(x: float,y: float,px: int=0,py: int=0,seed: int=0) -> float:
    var ix: int=int(floor(x))
    var iy: int=int(floor(y))
    var fx: float=x-ix
    var fy: float=y-iy
    var ux: float=fx*fx*(3-2*fx)
    var uy: float=fy*fy*(3-2*fy)
    var x0: int=posmod(ix,px) if px else ix
    var x1: int=posmod(ix+1,px) if px else ix+1
    var y0: int=posmod(iy,py) if py else iy
    var y1: int=posmod(iy+1,py) if py else iy+1
    return lerpf(lerpf(rand_hash([x0,y0,seed]),rand_hash([x1,y0,seed]),ux),lerpf(rand_hash([x0,y1,seed]),rand_hash([x1,y1,seed]),ux),uy)*2-1

static func fbm(x: float,y: float,seed: int=0,octaves: int=3) -> float:
    var s: float=0
    var a: float=.5
    var n: float=0
    for o in range(octaves):
        s+=noise2(x,y,seed+o*101)*a
        n+=a
        x*=2.03
        y*=2.03
        a*=.5
    return s/n if n>0 else 0.0

static func tile_fbm(x: float,y: float,px: int=0,py: int=0,seed: int=0,octaves: int=3) -> float:
    var s: float=0
    var a: float=.5
    var n: float=0
    var k: int=1
    for o in range(octaves):
        s+=tile_noise(x*k,y*k,px*k,py*k,seed+o*101)*a
        n+=a
        a*=.5
        k*=2
    return s/n if n>0 else 0.0

static func loop_noise(phase: float,radius: float=1,seed: int=0) -> float:
    var a: float=phase*TAU
    return noise2(cos(a)*radius+50,sin(a)*radius+50,seed)
