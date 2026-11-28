extends "res://lab/aura_study_002/hand.gd"
## The rendered fist is the very same center/radius used by the World.
func build_geometry(q:Dictionary,offset:Vector2)->void:
    seed.clear()
    detail.clear()
    growth=0.
    extension=0.
    if q.is_empty():return
    growth=float(q.g)
    if growth<.025:return
    var g:float=growth
    var axis:Vector2=q.axis
    var side:Vector2=axis.orthogonal()*float(q.facing)
    var wrist:Vector2=Vector2(q.wrist)+offset
    var elbow:Vector2=Vector2(q.elbow)+offset
    var center:Vector2=Vector2(q.center)+offset
    var radius:float=float(q.radius)
    var palm:Vector2=center-axis*4.8*g
    var start:Vector2=elbow.lerp(wrist,.4)
    var mid:Vector2=wrist.lerp(palm,.53)+side*.75*g
    var a:Vector2=start+side*1.6
    var b:Vector2=start-side*1.6
    var c:Vector2=mid-side*(2.+2.*g)
    var d:Vector2=palm-side*4.*g
    var e:Vector2=palm+side*4.*g
    var f:Vector2=mid+side*(2.+3.*g)
    seed.poly([[a.x,a.y],[b.x,b.y],[c.x,c.y],[d.x,d.y],[e.x,e.y],[f.x,f.y]],WHITE)
    # Rounded striking mass, separate knuckles within the declared circle.
    seed.circle(center.x,center.y,radius,WHITE)
    poly(seed,palm,axis,side,[[-2.*g,-4.*g],[3.*g,-5.*g],[5.*g,-4.5*g],[5.*g,4.5*g],[2.*g,5.*g],[-2.*g,4.*g]])
    for k in 4:
        var y:float=lerpf(-radius*.65,radius*.65,float(k)/3.)
        var knuckle:Vector2=center+axis*radius*.53+side*y
        seed.circle(knuckle.x,knuckle.y,maxf(.55,1.5*g),WHITE)
    var thumb:Vector2=center-axis*2.8*g-side*4.6*g
    seed.circle(thumb.x,thumb.y,maxf(.55,2.*g),WHITE)
    for k in 3:
        var y:float=lerpf(-radius*.45,radius*.45,float(k)/2.)
        stroke(detail,center-axis*1.5*g+side*y,center+axis*3.4*g+side*y,.7)
    tip=center+axis*radius
    extension=tip.distance_to(wrist)
