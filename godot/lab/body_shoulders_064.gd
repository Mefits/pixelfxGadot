extends RefCounted
# 064: shoulder and trapezius envelope on owner-approved 063 C.
# Variant C is B plus render-only inward humeral root correction.
const Previous=preload("res://lab/body_pelvis_063.gd")
var source=Previous.new(2)
var variant:int
func _init(i:int=0):
    variant=i

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    var chest:Vector2=q.chest
    var up:Vector2=(chest-Vector2(q.hips)).normalized()
    # Keep every lower trunk row (including .70) exact; change only the
    # clavicular shelf and the slope to the neck. No new bulbous caps.
    var trunk:Array=[]
    for row in p[0].sections:
        if float(row[0])<=.70:trunk.append(row.duplicate())
    trunk.append_array([[.84,4.80,4.80,3.35,0],[.96,4.72,4.72,3.06,0],
        [1.04,4.12,4.12,2.66,0],[1.12,3.10,3.10,2.14,0],
        [1.20,1.65,1.65,1.50,0]])
    p[0].sections=trunk
    # Only the base of the neck; head and distal neck untouched.
    p[1].sections[0]=[-.10,2.18,2.18,1.85,0]
    p[1].sections[1]=[.17,2.02,2.02,1.85,0]
    for k in 2:
        var side:String=["far","near"][k]
        var root:Vector2=q["shoulder_"+side]
        var elbow:Vector2=q["elbow_"+side]
        var axis:Vector2=(elbow-root).normalized()
        var transverse:=Vector2(-axis.y,axis.x)
        var medial:float=clampf((chest-root).dot(transverse)/5.,-1.,1.)
        var proxy:Vector2=root.lerp(chest,.24)
        var shoulder:Dictionary=p[2+6*k]
        var arm:Dictionary=p[3+6*k]
        # Lift the medial connector into the clavicular shelf. Choose the
        # same anchor for B and C, avoiding degenerate XY axes in either.
        var anchor:Vector2=chest-up*1.8
        if anchor.distance_to(root)<.45 or anchor.distance_to(proxy)<.45:
            anchor=chest+up*1.2
        if anchor.distance_to(root)<.45 or anchor.distance_to(proxy)<.45:
            anchor=chest-up*3.6
        shoulder.a[0]=anchor.x
        shoulder.a[1]=anchor.y
        shoulder.sections=[[-.20,1.52,1.52,1.55,0],[.10,2.02,2.02,2.02,0],
            [.42,2.12,2.12,2.06,0],[.72,1.86,1.86,1.92,0],
            [1.10,1.48,1.48,1.58,0]]
        # Extended taper above humeral origin; medial deltoid insertion.
        # Distal half and elbow overlap rows are exactly preserved.
        var rows:Array=[]
        var sgn:float=-1. if k==0 else 1.
        rows.append([-.22,.75,.75,.90,-sgn*.30])
        rows.append([-.12,1.43-medial*.18,1.43+medial*.18,1.48,-sgn*.24])
        for v in arm.sections:
            var t:float=v[0]
            if t<0.:continue
            if t>=.65:
                rows.append(v.duplicate())
                continue
            var f:float=1.-smoothstep(.24,.65,t)
            var width:float=lerpf((float(v[1])+float(v[2]))*.5,1.98,f)
            var shift:float=lerpf((float(v[2])-float(v[1]))*.5,medial*.34,f)
            rows.append([t,width-shift,width+shift,lerpf(float(v[3]),1.85,f),float(v[4])-sgn*.14*f])
        arm.sections=rows
        if variant==2:
            shoulder.b[0]=proxy.x
            shoulder.b[1]=proxy.y
            shoulder.b[2]*=.76
            arm.a[0]=proxy.x
            arm.a[1]=proxy.y
            arm.a[2]*=.76
    return p
