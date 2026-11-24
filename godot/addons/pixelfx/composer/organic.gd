extends RefCounted
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")

static func direction(l: Dictionary,base: Vector2,target: Vector2) -> float:
    var a: float=deg_to_rad(float(l.angle))
    if l.organic.aim and base.distance_squared_to(target)>.0001:
        a+=(target-base).angle()
    return a

static func centerline(l: Dictionary,base: Vector2,target: Vector2,age: float,arm: int,seed0: int) -> PackedVector2Array:
    var o: Dictionary=l.organic
    var rng=R.new(R.hash32([seed0,arm]))
    var phase: float=rng.between(0,TAU)
    var n: int=int(o.arms)
    var angle: float=direction(l,base,target)
    if n>1:angle+=deg_to_rad(float(l.spread))*(float(arm)/(n-1)-.5)
    var axis: Vector2=Vector2.from_angle(angle)
    var length: float=float(o.length)*(1.0+float(o.stretch)*sin(TAU*float(o.frequency)*age+phase))
    var steps: int=clampi(int(ceil(length/2.0)),8,P.MAX_ORGANIC_SEGMENTS)
    var points:=PackedVector2Array([base])
    for i in range(1,steps+1):
        var u: float=float(i)/steps
        var wave: float=sin(TAU*(1.2*u-float(o.frequency)*age)+phase)
        points.append(base+axis*length*u+axis.orthogonal()*float(o.wave)*u*u*wave)
    return points

static func mass_axes(l: Dictionary,size: float,age: float) -> Vector2:
    var o: Dictionary=l.organic
    var phase: float=sin(TAU*float(o.frequency)*age)
    var stretch: float=1.0+float(o.stretch)*phase
    var radius: float=size*(1.0+float(o.pulse)*phase)
    return Vector2(radius*stretch,radius/stretch)

static func draw(d,l: Dictionary,base: Vector2,target: Vector2,age: float,size: float,alpha: float,glow: float,color: int,seed0: int) -> int:
    if alpha<=.001:return 0
    var o: Dictionary=l.organic
    var dark: int=PAL.scale_color(color,.45)
    var work: int=0
    if l.type=="tendril":
        for arm in range(int(o.arms)):
            var points: PackedVector2Array=centerline(l,base,target,age,arm,seed0)
            for pass_index in range(2):
                for i in range(1,points.size()):
                    var a: Vector2=points[i-1]
                    var b: Vector2=points[i]
                    var steps: int=clampi(int(ceil(a.distance_to(b))),1,8)
                    for j in range(steps):
                        var f: float=float(j+1)/steps
                        var u: float=(float(i-1)+f)/(points.size()-1)
                        var q: Vector2=a.lerp(b,f)
                        var rad: float=maxf(.5,size*.5*(1.0-float(o.taper)*u)*(1.0+float(o.pulse)*sin(TAU*float(o.frequency)*age-u*4+arm)))
                        d.disc(q.x,q.y,rad+.7 if pass_index==0 else maxf(.5,rad-.4),dark if pass_index==0 else color,alpha)
                        if pass_index==1 and glow>.01 and j==steps-1 and i%4==0:
                            d.glow(q.x,q.y,maxf(2,rad*2),color,glow*alpha)
            work+=points.size()-1
        return work
    var axes: Vector2=mass_axes(l,size,age)
    var angle: float=direction(l,base,target)
    for pass_index in range(2):
        d.disc(base.x,base.y,maxf(.5,minf(axes.x,axes.y)*.7),dark if pass_index==0 else color,alpha)
        for i in range(24):
            var a: float=TAU*i/24.0
            var ripple: float=1.0+minf(.35,float(o.wave)/96.0)*sin(a*3+age*TAU*float(o.frequency))
            var tip: Vector2=Vector2(cos(a)*axes.x,sin(a)*axes.y).rotated(angle)*ripple
            var q: Vector2=base+tip*.62
            var rad: float=maxf(.5,tip.length()*.38)
            d.disc(q.x,q.y,rad+.7 if pass_index==0 else maxf(.5,rad-.4),dark if pass_index==0 else color,alpha)
    if glow>.01:d.glow(base.x,base.y,maxf(axes.x,axes.y),color,glow*alpha)
    return 24
