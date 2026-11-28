extends RefCounted
## Presentation-only articulated silhouette. All coordinates in art pixels.
const Aura=preload("res://lab/aura_study_001/aura.gd")
const Painter=preload("res://addons/pixelfx/native/painter.gd")
var seed=Painter.new(Aura.WIDTH,Aura.HEIGHT)
var detail=Painter.new(Aura.WIDTH,Aura.HEIGHT)
var growth:float=0.
var extension:float=0.
var tip:=Vector2.ZERO
const WHITE:int=0xffffffff

func shape_point(origin:Vector2,axis:Vector2,side:Vector2,x:float,y:float)->Array:
    var p:Vector2=origin+axis*x+side*y
    return [p.x,p.y]

func poly(painter,origin:Vector2,axis:Vector2,side:Vector2,points:Array)->void:
    var out:Array=[]
    for p in points:out.append(shape_point(origin,axis,side,p[0],p[1]))
    painter.poly(out,WHITE)

func stroke(painter,a:Vector2,b:Vector2,width:float)->void:
    painter.beam(a.x,a.y,b.x,b.y,width,WHITE)

func build(elbow:Vector2,wrist:Vector2,facing:float,age:int,mode:int)->void:
    seed.clear()
    detail.clear()
    growth=0.
    extension=0.
    tip=wrist
    if mode<2 or age<0:return
    # No change during hit-stop: age is the authoritative motion age.
    growth=smoothstep(2.,9.,float(age))*(1.-smoothstep(12.,20.,float(age)))
    if growth<.025:
        growth=0.
        return
    var forward:=Vector2(facing,0.)
    var axis:Vector2=(wrist-elbow).normalized()
    if axis.length_squared()<.01:axis=forward
    axis=forward.lerp(axis,.72).normalized()
    if axis.length_squared()<.01:axis=forward
    var side:Vector2=axis.orthogonal()*facing
    var g:float=growth
    var arm_length:float=(12. if mode==2 else 20.)*g
    var arm_width:float=2.+4.5*g
    var palm:Vector2=wrist+axis*arm_length
    var start:Vector2=elbow.lerp(wrist,.4)
    # Flared forearm connects to the existing wrist, not the opponent.
    var a:Vector2=start+side*1.6
    var b:Vector2=start-side*1.6
    var c:Vector2=palm-side*arm_width*.62
    var d:Vector2=palm+side*arm_width*.62
    seed.poly([[a.x,a.y],[b.x,b.y],[c.x,c.y],[d.x,d.y]],WHITE)
    if mode==2:
        # Closed fist: palm, four knuckle lobes, curled thumb and wrist.
        var length:float=9.*g
        var width:float=6.*g
        poly(seed,palm,axis,side,[[-2.*g,-width*.55],[length*.28,-width],[length*.81,-width],[length,-width*.64],[length,width*.60],[length*.70,width],[length*.05,width*.82],[-2.*g,width*.55]])
        for k in 4:
            var y:float=lerpf(-width*.70,width*.70,float(k)/3.)
            var p:Vector2=palm+axis*length*.83+side*y
            seed.circle(p.x,p.y,maxf(.65,1.75*g),WHITE)
        var thumb:Vector2=palm+axis*length*.32-side*width*.82
        seed.circle(thumb.x,thumb.y,maxf(.65,2.5*g),WHITE)
        for k in 3:
            var y:float=lerpf(-width*.5,width*.5,float(k)/2.)
            stroke(detail,palm+axis*length*.45+side*y,palm+axis*length*.91+side*y,.7)
        tip=palm+axis*(length+1.4*g)
    else:
        # Open striking palm with individually shaped, slightly spread fingers.
        var width:float=6.8*g
        var length:float=7.8*g
        poly(seed,palm,axis,side,[[-2.*g,-width*.50],[length*.30,-width],[length,-width*.73],[length,width*.80],[length*.25,width],[-2.*g,width*.50]])
        for k in 4:
            var u:float=float(k)/3.
            var y:float=lerpf(-width*.70,width*.70,u)
            var from:Vector2=palm+axis*length*.83+side*y
            var finger_length:float=[7.5,10.,9.,6.5][k]*g
            var joint:Vector2=from+axis*finger_length*.57+side*(u-.5)*2.*g
            var end:Vector2=joint+axis*finger_length*.43+side*(u-.5)*1.8*g
            stroke(seed,from,joint,maxf(.75,3.1*g))
            stroke(seed,joint,end,maxf(.65,2.4*g))
            seed.circle(end.x,end.y,maxf(.55,1.2*g),WHITE)
            stroke(detail,from+axis*.8*g,joint,.65)
        var thumb_start:Vector2=palm+axis*2.*g-side*width*.65
        var thumb_joint:Vector2=palm+axis*3.*g-side*width*1.35
        var thumb_end:Vector2=palm+axis*7.*g-side*width*1.48
        stroke(seed,thumb_start,thumb_joint,maxf(.8,3.8*g))
        stroke(seed,thumb_joint,thumb_end,maxf(.65,3.*g))
        seed.circle(thumb_end.x,thumb_end.y,maxf(.55,1.5*g),WHITE)
        tip=palm+axis*(length+10.*g)
    extension=tip.distance_to(wrist)
