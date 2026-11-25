extends RefCounted
## Lab adapter. A native loft itself only needs two XYZ points and local sections.
## Rows: axial fraction, left width, right width, thickness, center depth offset.
const BASE = preload("res://lab/body_skin_054.gd")
const DEFAULTS = {
    "trunk":[[-.25,.8,1.2,1.4,0],[-.17,3.65,3.95,3.05,0],[.04,4.35,4.25,3.65,0],
        [.32,3.1,3.35,2.9,0],[.65,4.1,4.4,3.65,.1],[.86,4.45,4.7,3.45,0],
        [1.01,3.65,3.8,2.85,0],[1.12,1.55,1.7,1.7,0]],
    "neck":[[-.08,2,2.1,1.8,0],[.2,2.25,2.15,2,0],[.58,1.65,1.6,1.55,0],[1,1.6,1.6,1.5,0]],
    "shoulder":[[-.15,1.15,1.1,1.2,0],[.45,2.0,2.1,1.85,0],[1.15,1.75,1.8,1.7,0]],
    "hip":[[-.15,1.6,1.6,1.5,0],[.5,2.6,2.4,2.15,0],[1.15,2.25,2.25,2.1,0]],
    "upper_arm":[[-.12,1.15,1.1,1.1,0],[0,1.85,1.9,1.8,0],[.24,2.15,2.35,2.2,0],
        [.65,1.85,2.1,1.95,0],[1,1.55,1.6,1.55,0],[1.11,.8,.8,.85,0]],
    "forearm":[[-.13,.8,.8,.9,0],[0,1.55,1.6,1.55,0],[.24,1.8,1.9,1.7,0],[.78,1.3,1.4,1.35,0],[1.06,1.15,1.2,1.2,0]],
    "thigh":[[-.12,1.55,1.55,1.45,0],[0,2.55,2.55,2.4,0],[.22,2.8,3.15,2.75,0],
        [.65,2.2,2.45,2.25,0],[1,1.85,1.85,1.8,0],[1.13,1,1,1.05,0]],
    "shin":[[-.13,.95,.95,1.1,0],[0,1.8,1.9,1.8,0],[.27,1.95,2.25,2.05,0],[.75,1.35,1.5,1.4,0],[1.07,1.16,1.25,1.2,0]]
}
var profiles: Dictionary
var coverings: Dictionary
var depth_scale: float
var bend_gain: float
var fold_lift: float
var exponents:Dictionary={}

func _init(shape: Dictionary={}, garments: Dictionary={}, depth_bias:float=1.0, flex_gain:float=.24, distal_lift:float=4.):
    profiles=DEFAULTS.duplicate(true)
    for role in shape:
        var override=shape[role]
        if override is Dictionary:
            profiles[role]=override.sections.duplicate(true)
            exponents[role]=override.get("profile",2.)
        else:
            profiles[role]=override.duplicate(true)
    coverings=garments.duplicate(true)
    depth_scale=depth_bias
    bend_gain=flex_gain
    fold_lift=distal_lift

# Keep FK evaluation, anatomical placement and wire-format preparation independently measurable.
func place(q:Dictionary)->Array:
    var h:Vector2=q.hips
    var c:Vector2=q.chest
    var up:Vector2=(c-h).normalized()
    var right:=Vector2(-up.y,up.x)
    var spans:Array=[["trunk",h,c,0.,0.,0.,0.],["neck",c,q.head,0.,0.,0.,0.]]
    for side in ["far","near"]:
        var sign_z:float=1. if side=="near" else -1.
        for arm in [true,false]:
            var root:Vector2=q[("shoulder_" if arm else "thigh_")+side]
            var pivot:Vector2=q[("elbow_" if arm else "knee_")+side]
            var end:Vector2=q[("hand_" if arm else "foot_")+side]
            var core:Vector2=c if arm else h
            var anchor:Vector2=c.lerp(h,.22) if arm else h.lerp(c,.15)
            if root.distance_squared_to(anchor)<.04:
                anchor+=up
            var half_span:float=5.5 if arm else 4.0
            var projected:float=clampf(absf((root-core).dot(right))/half_span,0.,1.)
            var z:float=sign_z*depth_scale*(2.0+1.3*sqrt(1.-projected*projected))
            var flex:float=(1.-(pivot-root).normalized().dot((end-pivot).normalized()))*.5
            spans.append(["shoulder" if arm else "hip",anchor,root,0.,z,0.,0.])
            spans.append(["upper_arm" if arm else "thigh",root,pivot,z,z,0.,flex])
            # At deep flexion the projected bones double back. A bounded linear
            # depth shear separates the distal end while the hinge stays welded.
            var end_z:float=z+sign_z*fold_lift*smoothstep(.45,1.,flex)
            spans.append(["forearm" if arm else "shin",pivot,end,z,end_z,flex,0.])
    return spans

func emit(spans:Array,q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var parts:Array=[]
    for s in spans:
        var role:String=s[0]
        var cover:Dictionary=coverings.get(role,{})
        var padding:float=cover.get("padding",0.)
        var sections:Array=[]
        for v in profiles[role]:
            var t:float=v[0]
            var local:float=s[5]*maxf(0.,1.-absf(t)/.35)+s[6]*maxf(0.,1.-absf(t-1.)/.35)
            sections.append([t,v[1]+padding,v[2]+padding,v[3]*(1.+bend_gain*local)+padding,v[4]])
        parts.append({"type":"loft","a":BASE.xyz(s[1],s[3]),"b":BASE.xyz(s[2],s[4]),
            "sections":sections,"profile":cover.get("profile",exponents.get(role,2.)),"part_id":parts.size()+1,
            "material_id":cover.get("material_id",0)})
    # Native analytic details remain interchangeable. The ends inherit their limb's depth.
    for k in 2:
        var side:String=["far","near"][k]
        var z:float=spans[4+6*k][4]
        var wrist:Vector2=q["hand_"+side]
        var dir:Vector2=(wrist-Vector2(q["elbow_"+side])).normalized()
        BASE.ell(parts,wrist+dir*.65,z,[2.25,1.65,1.8],dir.angle())
        var pitch:float=deg_to_rad(angles.get("foot_pitch_"+side,0.))
        BASE.ell(parts,Vector2(q["foot_"+side])+Vector2(1.2,-.8).rotated(pitch),spans[7+6*k][4],[3.,1.65,2.],pitch)
    BASE.ell(parts,q.head,0,[3.85,4.65,3.45],head_rotation)
    return parts
