extends RefCounted
# 066: expose the existing neck by lowering the trapezius envelope.
# Head, neck axis, true and visual shoulder roots and limbs stay fixed.
const Previous=preload("res://lab/body_trapezius_065.gd")
var source=Previous.new(2)
var variant:int
func _init(i:int=0):
    variant=i

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    var strength:float=.60 if variant==1 else 1.0
    var up:Vector2=(Vector2(q.chest)-Vector2(q.hips)).normalized()
    # Compress just the upper shelf along its existing axis. At t=1.20
    # the top is lowered by 0.96 / 1.60 rig px (16px trunk).
    # No neck elongation, no new gap in the neck/trunk attachment.
    var rows:Array=[]
    for v in p[0].sections:
        var row:Array=v.duplicate()
        var t:float=row[0]
        if t>.84:
            var w:float=(t-.84)/.36
            row[0]=t-.10*strength*w
            var narrow:float=.24*strength*smoothstep(.92,1.13,t)*(1.-smoothstep(1.14,1.20,t))
            row[1]-=narrow
            row[2]-=narrow
        rows.append(row)
    p[0].sections=rows
    # Remove a little flare from the neck base only. Its upper three
    # rows, bone axis, head and all depth values are unchanged.
    for j in [0,1]:
        var row:Array=p[1].sections[j].duplicate()
        var trim:float=(.28 if j==0 else .24)*strength
        row[1]-=trim
        row[2]-=trim
        p[1].sections[j]=row
    # Lower the superior-medial shoulder contour without moving either
    # attachment endpoint; retain depth and width on the lower side.
    # Reduce the correction as the arm elevates toward the neck.
    for k in 2:
        var side:String=["far","near"][k]
        var shoulder:Dictionary=p[2+6*k]
        var a:=Vector2(shoulder.a[0],shoulder.a[1])
        var b:=Vector2(shoulder.b[0],shoulder.b[1])
        var axis:Vector2=(b-a).normalized()
        var transverse:=Vector2(-axis.y,axis.x)
        var arm_dir:Vector2=(Vector2(q["elbow_"+side])-Vector2(q["shoulder_"+side])).normalized()
        var raised:float=smoothstep(-.1,.8,arm_dir.dot(up))
        var sign_up:float=up.dot(transverse)
        var shoulder_rows:Array=[]
        for v in shoulder.sections:
            var row:Array=v.duplicate()
            var t:float=row[0]
            var bell:float=smoothstep(-.20,.10,t)*(1.-smoothstep(.35,.86,t))
            var cut:float=.55*strength*bell*(1.-.65*raised)
            row[1]-=cut*maxf(0.,-sign_up)
            row[2]-=cut*maxf(0.,sign_up)
            shoulder_rows.append(row)
        shoulder.sections=shoulder_rows
    return p
