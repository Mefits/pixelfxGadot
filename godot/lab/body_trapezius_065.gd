extends RefCounted
# 065: reduce steep trapezius slope on 064 C, preserve all endpoint axes.
const Previous=preload("res://lab/body_shoulders_064.gd")
var source=Previous.new(2)
var variant:int
func _init(i:int=0):
    variant=i

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    # Broader superior clavicular shelf, rounded transition into the same neck.
    # Keep the lower trunk and chest at .84 exactly unchanged.
    var trunk:Array=[]
    for row in p[0].sections:
        if float(row[0])<=.84:trunk.append(row.duplicate())
    trunk.append_array([[.96,4.76,4.76,3.12,0],[1.04,4.53,4.53,2.86,0],
        [1.09,4.05,4.05,2.53,0],[1.14,3.20,3.20,2.08,0],
        [1.18,2.20,2.20,1.68,0],[1.20,1.65,1.65,1.50,0]])
    p[0].sections=trunk
    if variant==1:return p
    var up:Vector2=(Vector2(q.chest)-Vector2(q.hips)).normalized()
    # C: identical trunk to B; reshape only the connector cross-sections.
    # Upward bias follows torso orientation, fades at raised arm extremes
    # and at the medial/distal ends. Increase depth of the central join,
    # not the distal shoulder cap, to improve internal overlap.
    for k in 2:
        var side:String=["far","near"][k]
        var shoulder:Dictionary=p[2+6*k]
        var a:Vector2=Vector2(shoulder.a[0],shoulder.a[1])
        var b:Vector2=Vector2(shoulder.b[0],shoulder.b[1])
        var axis:Vector2=(b-a).normalized()
        var transverse:=Vector2(-axis.y,axis.x)
        var arm_dir:Vector2=(Vector2(q["elbow_"+side])-Vector2(q["shoulder_"+side])).normalized()
        var raised:float=smoothstep(-.1,.8,arm_dir.dot(up))
        var rows:Array=[]
        for v in shoulder.sections:
            var t:float=v[0]
            var bell:float=smoothstep(-.20,.30,t)*(1.-smoothstep(.62,1.10,t))
            var shift:float=.32*bell*up.dot(transverse)*(1.-.65*raised)
            var width:float=.10*bell
            rows.append([t,float(v[1])+width-shift,float(v[2])+width+shift,
                float(v[3])+.40*bell,float(v[4])])
        shoulder.sections=rows
    return p
