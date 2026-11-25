extends RefCounted
# 068 combined baseline: 066 B, 067 B arm proportions, 067 C pelvic tip.
# Optional artistic extremity refinements; no articulated fingers yet.
const Pelvis=preload("res://lab/body_pelvis_tip_067.gd")
const Base=preload("res://lab/body_skin_054.gd")
const SizedRig=preload("res://lab/anatomy_rd/rig_proportions_067.gd")
var body=Pelvis.new()
var variant:int
func _init(i:int=0):
    variant=i

static func make_rig():
    return SizedRig.create(.90,.90)

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=body.make(q,angles,head_rotation,2)
    if variant==0:return p
    for k in 2:
        var side:String=["far","near"][k]
        var wrist:Vector2=q["hand_"+side]
        var dir:Vector2=(wrist-Vector2(q["elbow_"+side])).normalized()
        var idx:int=14+2*k
        var z:float=p[idx].center[2]
        # Same wrist, same depth lane. Short rounded mitten/fist with
        # wrist flare, broad knuckle band and tapered distal edge.
        var end:Vector2=wrist+dir*2.55
        p[idx]={"type":"loft","part_id":p[idx].part_id,"material_id":p[idx].material_id,
            "a":Base.xyz(wrist,z),"b":Base.xyz(end,z),"profile":2.65,
            "sections":[[-.56,.42,.42,.60,0],[-.36,1.00,1.00,1.18,0],
                [-.08,1.20,1.20,1.38,0],[.26,1.43,1.43,1.60,0],
                [.59,1.52,1.45,1.65,0],[.83,1.32,1.30,1.46,0],
                [.99,.85,.82,1.08,0],[1.07,.28,.28,.42,0]]}
        if variant==1:continue
        # Same heel/toe axis, ankle anchor and pitch. Round heel and toe,
        # reduce bulbous instep, retain a nearly level plantar edge.
        var f:Dictionary=p[15+2*k]
        f.sections=[[0,.54,.49,.88,0],[.10,1.06,.62,1.36,0],
            [.22,1.57,.65,1.70,0],[.34,1.70,.65,1.75,0],
            [.52,1.18,.65,1.67,0],[.72,.90,.65,1.53,0],
            [.89,.78,.63,1.36,0],[.99,.55,.48,.98,0],[1.03,.30,.30,.55,0]]
    return p
