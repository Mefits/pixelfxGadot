extends RefCounted
# Separate, optional pelvis-tip experiment. Same accepted 066 B geometry
# and same original rig; do not conflate it with the arm proportions.
const Previous=preload("res://lab/body_neck_066.gd")
var source=Previous.new(1)
func make(q:Dictionary,angles:Dictionary,head_rotation:float,variant:int=0)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    var up:Vector2=(Vector2(q.chest)-Vector2(q.hips)).normalized()
    var swing:float=0.
    for side in ["far","near"]:
        var dir:Vector2=(Vector2(q["knee_"+side])-Vector2(q["thigh_"+side])).normalized()
        swing=maxf(swing,smoothstep(-.85,.25,dir.dot(up)))
    # Preserve all sections at or above the hip plane; compress only the
    # distal central wedge during leg swing. Make its tiny final section
    # rounder and shorter instead of a projecting triangular tip.
    var strength:float=.55 if variant==1 else 1.
    var factor:float=strength*swing
    var rows:Array=[]
    for v in p[0].sections:
        var row:Array=v.duplicate()
        var t:float=row[0]
        if t<0.:
            var weight:float=smoothstep(0.,.20,-t)
            row[0]=t*(1.-.34*factor*weight)
            row[3]*=1.-.22*factor*weight
            if t<-.16:
                row[1]*=1.-.12*factor*weight
                row[2]*=1.-.12*factor*weight
        rows.append(row)
    p[0].sections=rows
    return p
