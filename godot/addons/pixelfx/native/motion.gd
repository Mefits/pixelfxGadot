extends RefCounted
## Closed-form flight, direct port of src/core/particles.js, MIT Patch/Hugo Duprez.
const M=preload("res://addons/pixelfx/native/math.gd")
## Return arrays to retain double precision in art-pixel coordinates.
static func fly(x: float,y: float,vx: float,vy: float,t: float,g: float=0.0,drag: float=0.0) -> Array:
    if drag<=0.0:
        return [x+vx*t,y+vy*t+0.5*g*t*t]
    var f: float=(1.0-exp(-drag*t))/drag
    var vt: float=g/drag
    return [x+vx*f,y+vt*t+(vy-vt)*f]

static func velocity(vx: float,vy: float,t: float,g: float=0.0,drag: float=0.0) -> Array:
    if drag<=0.0:
        return [vx,vy+g*t]
    var e: float=exp(-drag*t)
    var vt: float=g/drag
    return [vx*e,vt+(vy-vt)*e]

static func burst(n: int,seed: int,fn: Callable) -> void:
    for i in range(n):
        fn.call(M.rng_for([seed,i]),i)

static func cycle(t: float,period: float,count: int,seed: int,life: Variant,fn: Callable) -> void:
    if period<=0:
        return
    for i in range(count):
        var g=M.rng_for([seed,i,911])
        var born: float=g.next()*period
        var length: float=life.call(g) if life is Callable else float(life)
        var age: float=M.wrap(t-born,period)
        while age<length:
            fn.call(age,length,M.rng_for([seed,i]),i)
            age+=period

static func stream(t: float,t0: float,t1: float,rate: float,seed: int,life: Variant,fn: Callable) -> void:
    if rate<=0:
        return
    var n: int=int(floor((minf(t,t1)-t0)*rate))
    for i in range(n+1):
        var born: float=t0+i/rate
        var g=M.rng_for([seed,i,911])
        var length: float=life.call(g) if life is Callable else float(life)
        var age: float=t-born
        if age>=0 and age<length:
            fn.call(age,length,M.rng_for([seed,i]),i)
