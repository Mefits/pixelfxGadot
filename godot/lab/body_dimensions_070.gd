extends RefCounted
# Same skeleton topology, clips and native Loft for every preset.
# Artistic presets, not anthropometric reconstructions of a named character.
const Previous=preload("res://lab/body_ankle_069.gd")
const Rig=preload("res://lab/anatomy_rd/rig_dimensions_070.gd")
const PRESETS=[
    {"name":"adult","torso":1.,"neck":1.,"leg":1.,"upper":1.,"fore":1.,"shoulder":1.,"hip":1.,"chest":1.,"waist":1.,"limb":1.,"depth":1.,"head":1.,"hand":1.,"foot":1.},
    {"name":"youth","torso":.82,"neck":.87,"leg":.82,"upper":.82,"fore":.82,"shoulder":.76,"hip":.80,"chest":.76,"waist":.83,"limb":.76,"depth":.80,"head":.94,"hand":.81,"foot":.83},
    {"name":"tall lean","torso":1.06,"neck":1.08,"leg":1.12,"upper":1.08,"fore":1.10,"shoulder":.93,"hip":.91,"chest":.91,"waist":.89,"limb":.87,"depth":.93,"head":.97,"hand":1.,"foot":1.08},
    {"name":"compact broad","torso":.94,"neck":.94,"leg":.89,"upper":.92,"fore":.92,"shoulder":1.12,"hip":1.08,"chest":1.16,"waist":1.12,"limb":1.13,"depth":1.10,"head":1.02,"hand":1.04,"foot":.98}
]
var source=Previous.new(2)
var shape:Dictionary
func _init(i:int=0):
    shape=PRESETS[i].duplicate(true)
static func make_rig(i:int=0):
    return Rig.create(PRESETS[i])

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if shape.name=="adult":return p
    var d:float=shape.depth
    # Proportions are per-role; no image scaling. The 069 deformation
    # algorithm has already run on this character's real FK axes.
    for i in p.size():
        var v:Dictionary=p[i]
        if i==18:
            for j in 3:v.radii[j]*=float(shape.head)
            v.center[2]*=d
            continue
        var role:int=(i-2)%6 if i>=2 and i<14 else -1
        var w:float=1.
        if i==1:w=lerpf(float(shape.chest),float(shape.head),.30)
        elif role==0:w=lerpf(float(shape.shoulder),float(shape.limb),.40)
        elif role==3:w=lerpf(float(shape.hip),float(shape.limb),.40)
        elif role in [1,2,4,5]:w=shape.limb
        elif i in [14,16]:w=shape.hand
        elif i in [15,17]:w=shape.foot
        v.a[2]*=d
        v.b[2]*=d
        if i>=14:
            var side:String="far" if i<16 else "near"
            var center:Vector2=q[("hand_" if i in [14,16] else "foot_")+side]
            var s:float=shape.hand if i in [14,16] else shape.foot
            for key in ["a","b"]:
                var a:Vector2=center+(Vector2(v[key][0],v[key][1])-center)*s
                v[key][0]=a.x
                v[key][1]=a.y
        for row in v.sections:
            var width:float=w
            if i==0:
                var t:float=row[0]
                width=lerpf(float(shape.hip),float(shape.waist),smoothstep(0.,.42,t))
                width=lerpf(width,float(shape.chest),smoothstep(.42,.84,t))
            elif i==1:
                width=lerpf(float(shape.chest),float(shape.head),smoothstep(-.1,.88,float(row[0]))*.48)
            row[1]*=width
            row[2]*=width
            row[3]*=d
            row[4]*=d
    return p
