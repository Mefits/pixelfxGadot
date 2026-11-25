extends RefCounted
# 0.60: lower torso and pelvic insertion only; original FK and upper body unchanged.
const Previous=preload("res://lab/body_anatomy_059.gd")
var source=Previous.new(3)
var variant:int
func _init(i:int=0):
    variant=i
func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    # Ref waist/chest ~.75; pelvic crest/chest ~.83. Retain chest width 9.6.
    # Taper the lower central mass to the crotch rather than a horizontal cut.
    var trunk:Array=[
        [-.36,.50,.50,.95,0],[-.30,1.28,1.28,1.75,0],[-.22,2.65,2.65,2.60,0],
        [-.12,3.90,3.90,3.20,0],[.02,4.12,4.12,3.40,0],[.18,3.92,3.92,3.10,0],
        [.32,3.65,3.65,2.95,0],[.44,3.60,3.60,2.87,0],[.64,4.30,4.30,3.35,0],
        [.84,4.80,4.80,3.35,0],[1.0,4.30,4.30,2.8,0],[1.12,2.6,2.6,1.85,0],[1.20,1.65,1.65,1.5,0]]
    p[0].sections=trunk
    for k in 2:
        var hip:Dictionary=p[5+6*k]
        var thigh:Dictionary=p[6+6*k]
        # Broad medial root, narrower lateral connector; bury it in trunk and femoral volume.
        hip.sections=[[-.20,1.85,1.85,1.8,0],[.16,2.30,2.30,2.25,0],[.45,2.30,2.30,2.20,0],[.85,2.12,2.12,2.0,0],[1.15,2.05,2.05,1.95,0]]
        if variant==1:continue
        var side:String=["far","near"][k]
        var root:Vector2=q["thigh_"+side]
        var knee:Vector2=q["knee_"+side]
        var axis:Vector2=(knee-root).normalized()
        var transverse:=Vector2(-axis.y,axis.x)
        var inward:float=clampf((Vector2(q.hips)-root).normalized().dot(transverse),-1.0,1.0)
        var depth_sign:float=1.0 if k==1 else -1.0
        # Local inward section offset, not a moved joint. Proximal volume extends
        # into the pelvis and recovers the original center/depth toward the knee.
        hip.b[2]-=depth_sign*.52
        var orig:Array=thigh.sections
        var rows:Array=[[-.24,1.1,1.1,1.25,-depth_sign*.72],[-.13,2.12,2.12,2.0,-depth_sign*.65]]
        for row in orig:
            var t:float=row[0]
            if t<0:continue
            var w:float=1.0-smoothstep(.12,.62,t)
            var width:float=(float(row[1])+float(row[2]))*.5
            var move:float=inward*.42*w
            var widen:float=.12*w
            rows.append([t,width+widen-move,width+widen+move,row[3],float(row[4])-depth_sign*.52*w])
        thigh.sections=rows
    return p
