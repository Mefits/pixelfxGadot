extends RefCounted
# Art profiles only. Native loft implementation and source FK remain unchanged.
const Loft=preload("res://lab/body_deformation_058.gd")
const Base=preload("res://lab/body_skin_054.gd")
var body
var kind:int
func _init(variant:int=0):
    kind=variant
    if kind==0:
        body=Loft.new()
        return
    var shape:Dictionary={}
    # Common, deliberately flatter trunk with continuous trapezius line, less
    # pelvis bulge and narrower joints than the old spherical construction.
    var trunks:Array=[
        [[-.24,1.05,1.05,1.3,0],[-.16,3.05,3.05,2.65,0],[.02,3.75,3.75,3.0,0],[.23,3.38,3.38,2.8,0],[.40,3.3,3.3,2.75,0],[.64,4.0,4.0,3.25,0],[.84,4.55,4.55,3.35,0],[1.0,4.1,4.1,2.65,0],[1.12,2.55,2.55,1.85,0],[1.20,1.65,1.65,1.5,0]],
        [[-.24,1.1,1.1,1.45,0],[-.16,3.4,3.4,2.95,0],[.02,4.05,4.05,3.2,0],[.23,3.55,3.55,3.0,0],[.40,3.55,3.55,3.0,0],[.64,4.65,4.65,3.85,0],[.84,5.0,5.0,3.85,0],[1.0,4.5,4.5,3.1,0],[1.12,2.9,2.9,2.15,0],[1.21,1.85,1.85,1.65,0]],
        [[-.24,1.0,1.0,1.3,0],[-.16,3.1,3.1,2.65,0],[.02,3.85,3.85,3.05,0],[.23,3.25,3.25,2.75,0],[.40,3.15,3.15,2.65,0],[.64,4.3,4.3,3.35,0],[.84,4.8,4.8,3.35,0],[1.0,4.3,4.3,2.8,0],[1.12,2.6,2.6,1.85,0],[1.20,1.65,1.65,1.5,0]]]
    shape.trunk={"sections":trunks[kind-1],"profile":2.25 if kind<3 else 2.6}
    shape.neck={"sections":[[-.10,2.25,2.25,1.85,0],[.17,2.05,2.05,1.85,0],[.38,1.57,1.57,1.45,0],[.66,1.45,1.45,1.4,0],[.88,1.62,1.62,1.5,0]],"profile":2.15}
    # Keep attachment endpoints generously buried. Do not widen a shoulder
    # sphere or alter the underlying shoulder/hip joints.
    shape.shoulder={"sections":[[-.20,1.65,1.65,1.6,0],[.26,2.05,2.05,1.85,0],[.72,1.88,1.88,1.78,0],[1.13,1.76,1.76,1.68,0]],"profile":2.25}
    shape.hip={"sections":[[-.20,1.8,1.8,1.7,0],[.35,2.28,2.28,2.05,0],[.78,2.25,2.25,2.05,0],[1.18,2.23,2.23,2.1,0]],"profile":2.2}
    var limb_scales:Array=[[.90,.92,.94,.95],[1.12,1.10,1.10,1.08],[.96,.94,1.01,.96]]
    var scales:Array=limb_scales[kind-1]
    for i in 4:
        var role:String=["upper_arm","forearm","thigh","shin"][i]
        var rows:Array=Loft.DEFAULTS[role].duplicate(true)
        # Preserve overlap rows at joints; adjust midsegment anatomy.
        for j in rows.size():
            var t:float=rows[j][0]
            var factor:float=lerpf(1.0,scales[i],smoothstep(0.0,.22,t)*(1.0-smoothstep(.72,1.0,t)))
            rows[j][1]*=factor
            rows[j][2]*=factor
            rows[j][3]*=factor
        shape[role]={"sections":rows,"profile":2.1 if kind<3 else 2.35}
    body=Loft.new(shape)
func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var spans:Array=body.place(q)
    var parts:Array=body.emit(spans,q,angles,head_rotation)
    if kind==0:return parts
    # Lower only the rendered head, not the head anchor or clip.
    var head:Vector2=q.head
    var chest:Vector2=q.chest
    var at:Vector2=head.lerp(chest,.18 if kind<3 else .20)
    parts[18].center=Base.xyz(at,0)
    parts[18].radii=[3.65,4.45,3.3] if kind<3 else [4.05,4.65,3.5]
    # Foot profile: defined heel, ankle/instep, flatter sole and tapered toe.
    # Same pitch and depth as 0.58; ankle stays the explicit origin.
    for k in 2:
        var side:String=["far","near"][k]
        var foot:Vector2=q["foot_"+side]
        var pitch:float=deg_to_rad(float(angles.get("foot_pitch_"+side,0.0)))
        var a:Vector2=foot+Vector2(-1.65,-.30).rotated(pitch)
        var b:Vector2=foot+Vector2(3.75,-.30).rotated(pitch)
        var z:float=spans[7+6*k][4]
        var idx:int=15+2*k
        parts[idx]={"type":"loft","part_id":parts[idx].part_id,"material_id":0,"a":Base.xyz(a,z),"b":Base.xyz(b,z),"profile":2.4,
            "sections":[[0,.66,.62,1.05,0],[.14,1.35,.65,1.6,0],[.32,1.85,.65,1.8,0],[.56,1.25,.65,1.76,0],[.80,.86,.65,1.6,0],[.96,.67,.57,1.18,0],[1.03,.43,.42,.75,0]]}
    return parts
