extends RefCounted
## Closed-form flight, direct port of src/core/particles.js, MIT Patch/Hugo Duprez.
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
