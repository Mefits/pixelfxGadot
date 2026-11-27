extends RefCounted
## Small profile boundary: body factory and stance settings, not a new motion engine.
const Body=preload("res://lab/body_ankle_069.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const PROFILE_PATH="res://lab/profiles/default_fighter.json"
const BASE={"body":{"id":"lab_humanoid_069","rig_preset":"humanoid_069"},"guard":{"id":"standard_guard","width_scale":1.0}}
const MIN_WIDTH:float=.85
const MAX_WIDTH:float=1.15

static func load_profile(overrides:Dictionary={})->Dictionary:
    var raw:Dictionary={}
    if not overrides.is_empty():
        raw=overrides
    elif FileAccess.file_exists(PROFILE_PATH):
        var parsed=JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
        if parsed is Dictionary:raw=parsed
        else:push_warning("Invalid fighter profile JSON; using standard profile")
    var result:Dictionary=BASE.duplicate(true)
    var body=raw.get("body",{})
    if body is Dictionary:
        if body.get("rig_preset","humanoid_069")!="humanoid_069":
            push_warning("Unsupported rig preset; using humanoid_069")
        else:
            result.body.id=str(body.get("id",result.body.id))
            # Only the accepted geometry/render preset is supported in v8.
    var guard=raw.get("guard",{})
    if guard is Dictionary:
        result.guard.id=str(guard.get("id",result.guard.id))
        var scale=guard.get("width_scale",1.0)
        if (scale is float or scale is int) and is_finite(float(scale)):
            result.guard.width_scale=clampf(float(scale),MIN_WIDTH,MAX_WIDTH)
        else:push_warning("Invalid guard width; using 1.0")
    return result

static func make_rig(profile:Dictionary):
    assert(profile.body.rig_preset=="humanoid_069")
    return Body.make_rig()

static func make_body(profile:Dictionary):
    assert(profile.body.rig_preset=="humanoid_069")
    return Body.new(2)

# Scale the authored contact span around its own midpoint, not world zero.
# At 1.0 the original intent is untouched (including precision and load).
static func apply_guard(value:Dictionary,profile:Dictionary)->Dictionary:
    var scale:float=profile.guard.width_scale
    if scale==1.0:return value
    var a:Vector2=value.paths[0].toe
    var b:Vector2=value.paths[1].toe
    var center:float=(a.x+b.x)*.5
    a.x=center+(a.x-center)*scale
    b.x=center+(b.x-center)*scale
    value.paths[0].toe=Grid.point(a)
    value.paths[1].toe=Grid.point(b)
    if value.has("support_load"):
        var load_near:float=clampf(.5+(float(value.support_load[0])-.5)/scale,.12,.88)
        value.support_load=[load_near,1.-load_near]
    return value
