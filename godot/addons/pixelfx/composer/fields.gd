extends RefCounted
## Bounded procedural field geometry. No gameplay collision or screen shader.
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const MAX_ARCS=8
const MAX_STEPS=96

static func axis(l: Dictionary,pos: Vector2,target: Vector2) -> float:
    var a: float=deg_to_rad(float(l.angle))
    if l.field.aim and pos.distance_squared_to(target)>.0001:a+=(target-pos).angle()
    return a

static func ellipse_point(center: Vector2,rad: float,aspect: float,angle: float,rot: float) -> Vector2:
    return center+Vector2(cos(angle)*rad,sin(angle)*rad*aspect).rotated(rot)

static func stroke(d,a: Vector2,b: Vector2,width: float,color: int,alpha: float) -> void:
    if width<=1.5:
        d.line(a.x,a.y,b.x,b.y,color,alpha)
        return
    var normal: Vector2=(b-a).normalized().orthogonal()
    var n: int=clampi(int(ceil(width)),2,12)
    for i in range(n):
        var off: Vector2=normal*(float(i)/(n-1)-.5)*width
        d.line(a.x+off.x,a.y+off.y,b.x+off.x,b.y+off.y,color,alpha)

static func arc(d,pos: Vector2,rad: float,aspect: float,rot: float,start: float,sweep: float,width: float,color: int,alpha: float) -> int:
    var n: int=clampi(int(ceil(absf(sweep)*rad/2.0)),8,MAX_STEPS)
    var a: Vector2=ellipse_point(pos,rad,aspect,start,rot)
    for i in range(1,n+1):
        var b: Vector2=ellipse_point(pos,rad,aspect,start+sweep*float(i)/n,rot)
        stroke(d,a,b,width,color,alpha)
        a=b
    return n

static func draw(d,l: Dictionary,pos: Vector2,target: Vector2,age: float,size: float,alpha: float,glow: float,color: int,seed0: int) -> int:
    if alpha<=.001:return 0
    var f: Dictionary=l.field
    var rot: float=axis(l,pos,target)
    var spin: float=deg_to_rad(float(f.rotation))*age
    var width: float=float(f.thickness)
    var aspect: float=float(f.aspect)
    var distortion: float=float(f.distortion)
    var bright: int=PAL.mix(color,PAL.from_hex("#ffffff"),.7)
    var dark: int=PAL.scale_color(color,.2)
    var n: int=clampi(int(l.count),1,MAX_ARCS)
    var work: int=0
    match l.type:
        "shockwave":
            for i in range(n):
                var rad: float=size-i*(width+2)
                if rad<.5:continue
                work+=arc(d,pos,rad,aspect,rot,0,TAU,width,color,alpha*(1.0-float(i)/n)*.8)
            if glow>.01:d.glow(pos.x,pos.y,size,color,glow*alpha*.25)
        "beam":
            var v: Vector2=Vector2.from_angle(rot)
            var normal: Vector2=v.orthogonal()
            var length: float=float(f.length)
            if f.aim:length=minf(length,pos.distance_to(target))
            if length<.5:return 0
            var prev: Vector2=pos
            var steps: int=clampi(int(ceil(length/3.0)),2,64)
            for i in range(1,steps+1):
                var u: float=float(i)/steps
                var q: Vector2=pos+v*length*u+normal*sin(u*TAU*2+spin)*sin(u*PI)*distortion*size
                stroke(d,prev,q,clampf(size+width,1,12),color,alpha*.55)
                stroke(d,prev,q,clampf(width,1,12),bright,alpha)
                if glow>.01 and i%4==0:d.glow(q.x,q.y,maxf(2,size*2),color,glow*alpha*.7)
                prev=q
            work+=steps
        "vortex":
            for i in range(n):
                var phase: float=TAU*float(i)/n+spin
                var prev: Vector2=pos
                for j in range(1,49):
                    var u: float=float(j)/48
                    var rad: float=size*u
                    var angle: float=phase+TAU*u*(.75+distortion*1.5)
                    var q: Vector2=ellipse_point(pos,rad,aspect,angle,rot)
                    stroke(d,prev,q,width*(.3+.7*u),color,alpha*(.3+.7*u))
                    prev=q
                work+=48
            if glow>.01:d.glow(pos.x,pos.y,size*.8,color,glow*alpha*.45)
        "orb":
            d.disc(pos.x,pos.y,size,dark,alpha*.85)
            d.disc(pos.x,pos.y,size*.64,color,alpha*.65)
            d.disc(pos.x,pos.y,size*.26,bright,alpha)
            for i in range(n):
                work+=arc(d,pos,size*(.72+.18*float(i)/n),aspect,rot+spin+PI*float(i)/n,0,TAU,width*.5,bright,alpha*.7)
            if glow>.01:d.glow(pos.x,pos.y,size*1.5,color,glow*alpha)
        "rift":
            var v: Vector2=Vector2.from_angle(rot)
            var normal: Vector2=v.orthogonal()
            var half_length: float=float(f.length)*.5
            var rng=RNG.new(seed0)
            var phase: float=rng.between(0,TAU)
            var prev: Vector2=pos-v*half_length
            var old_width: float=0
            for i in range(1,49):
                var u: float=float(i)/48
                var envelope: float=sin(u*PI)
                var q: Vector2=pos+v*((2*u-1)*half_length)+normal*sin(u*TAU*3+phase+spin)*distortion*size*envelope
                var w: float=maxf(.5,envelope*size*(.85+.15*sin(u*TAU*5+spin)))
                # Dark interior and two independently drawn luminous edges.
                stroke(d,prev,q,clampf(w*2,1,12),dark,alpha)
                var aa: Vector2=prev+normal*old_width
                var bb: Vector2=q+normal*w
                stroke(d,aa,bb,width,bright,alpha)
                aa=prev-normal*old_width
                bb=q-normal*w
                stroke(d,aa,bb,width,color,alpha)
                if glow>.01 and i%4==0:d.glow(q.x,q.y,maxf(2,w*2),color,glow*alpha*.55)
                prev=q
                old_width=w
            work+=48
    return work
