extends RefCounted
# 063: reference-guided envelopes; visual root correction is separately switchable.
# Reference 062 width measurements are targets for the *combined* projected
# envelope, not literal individual Loft radii or inferred joint positions.
const Previous=preload("res://lab/body_pelvis_060.gd")
var source=Previous.new(2)
var variant:int
func _init(i:int=0):
    variant=i

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    var h:Vector2=q.hips
    var up:Vector2=(Vector2(q.chest)-h).normalized()
    var raise:float=0.
    for side in ["far","near"]:
        var down:Vector2=(Vector2(q["knee_"+side])-Vector2(q["thigh_"+side])).normalized()
        raise=maxf(raise,smoothstep(.25,.9,down.dot(up)))
    # Map reference chest slice y650 to t=.84, waist y825 to .42,
    # pelvic level y1000 to ~0. The lower trunk is only the CENTRAL
    # component of the combined envelope; upper thighs supply the rest.
    # Shorten the central distal tip during raised-leg poses, not the rig.
    var trunk:Array=[
        [-.30,.48,.48,.80,0],[-.25,1.45,1.45,1.60,0],
        [-.19,2.85,2.85,2.40,0],[-.10,4.18,4.18,3.12,0],
        [.00,4.20,4.20,3.40,0],[.10,4.00,4.00,3.30,0],
        [.23,3.72,3.72,3.08,0],[.42,3.55,3.55,2.90,0],
        [.57,3.84,3.84,3.08,0],[.70,4.33,4.33,3.35,0],
        [.84,4.80,4.80,3.35,0],[1.0,4.30,4.30,2.8,0],
        [1.12,2.6,2.6,1.85,0],[1.20,1.65,1.65,1.5,0]]
    for row in trunk:
        if row[0]<0.:
            row[0]*=lerpf(1.,.68,raise)
            row[3]*=lerpf(1.,.83,raise)
    p[0].sections=trunk
    for k in 2:
        var side:String=["far","near"][k]
        var root:Vector2=q["thigh_"+side]
        var knee:Vector2=q["knee_"+side]
        var axis:Vector2=(knee-root).normalized()
        var transverse:=Vector2(-axis.y,axis.x)
        # Continuous signed medial direction. At coincident projected roots
        # the asymmetric XY offset smoothly tends to zero, not a side flip.
        var medial:float=clampf((h-root).dot(transverse)/4.,-1.,1.)
        var hip:Dictionary=p[5+6*k]
        var thigh:Dictionary=p[6+6*k]
        hip.sections=[[-.20,1.55,1.55,1.7,0],[.10,2.35,2.35,2.35,0],
            [.44,2.50,2.50,2.45,0],[.76,2.30,2.30,2.22,0],[1.10,1.90,1.90,1.92,0]]
        # Proximal reference individual thigh width ~4.56 rig px for
        # 9.6px chest; bias the mass medially, taper toward the knee.
        # Reuse the existing axial depth and flex values.
        var rows:Array=[]
        for v in thigh.sections:
            var t:float=v[0]
            var width:float=(float(v[1])+float(v[2]))*.5
            var shift:float=(float(v[2])-float(v[1]))*.5
            if t<=.22:
                width=lerpf(1.15,2.30,smoothstep(-.24,.0,t))
                shift=medial*.58*smoothstep(-.24,-.05,t)
            elif t<.65:
                var w:float=1.-smoothstep(.22,.65,t)
                width=lerpf(width,2.30,w)
                shift=lerpf(shift,medial*.58,w)
            rows.append([t,width-shift,width+shift,v[3],v[4]])
        thigh.sections=rows
        if variant==2:
            # Same rows as B. Render-only endpoint correction: keep the
            # true knee, its z, shins, feet and all source FK/IK unchanged.
            var proxy:Vector2=root.lerp(h,.27)
            hip.b[0]=proxy.x
            hip.b[1]=proxy.y
            hip.b[2]*=.78
            thigh.a[0]=proxy.x
            thigh.a[1]=proxy.y
            thigh.a[2]*=.78
    return p
