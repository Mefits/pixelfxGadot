extends "res://lab/spatial_lab/spatial_roundhouse.gd"
## 007 only. Artistic profiles share the same signed turn, attack clock,
## world toe anchor, IK, MotionEntry and diagnostic contact as control.
## No changes to the authoritative 2D actor.
const PROFILES=[
    [[0.,0.],[10.,-65.],[13.,0.],[18.,115.],[26.,265.],[36.,360.]],
    [[0.,0.],[8.,-32.],[10.,-28.],[13.,0.],[18.,97.],[26.,247.],[33.,342.],[36.,360.]],
    [[0.,0.],[9.,-48.],[10.,-40.],[13.,0.],[16.,111.],[20.,211.],[27.,307.],[36.,360.]],
    [[0.,0.],[9.,-73.],[10.,-63.],[13.,0.],[16.,125.],[19.,223.],[27.,327.],[36.,360.]]
]
var profile:int=0
var frozen_profile:int=0

func begin(isolated,initial_yaw:int=0)->bool:
    if active:return false
    frozen_profile=clampi(profile,0,3)
    return super.begin(isolated,initial_yaw)

# Piecewise cubic monotone Hermite: zero slope only at extrema and
# endpoints, not every key. Retain the signed winding and impact angle.
static func slope(keys:Array,i:int)->float:
    if i==0 or i==keys.size()-1:return 0.
    var a:float=(float(keys[i][1])-float(keys[i-1][1]))/(float(keys[i][0])-float(keys[i-1][0]))
    var b:float=(float(keys[i+1][1])-float(keys[i][1]))/(float(keys[i+1][0])-float(keys[i][0]))
    if a*b<=0.:return 0.
    return 2.*a*b/(a+b)

static func curve(keys:Array,t:float)->float:
    if t<=float(keys[0][0]):return float(keys[0][1])
    for i in range(keys.size()-1):
        var lo:Array=keys[i]
        var hi:Array=keys[i+1]
        if t>float(hi[0]):continue
        var dt:float=float(hi[0])-float(lo[0])
        var u:float=clampf((t-float(lo[0]))/dt,0.,1.)
        var u2:float=u*u
        var u3:float=u2*u
        return (2.*u3-3.*u2+1.)*float(lo[1])+(u3-2.*u2+u)*dt*slope(keys,i)+(-2.*u3+3.*u2)*float(hi[1])+(u3-u2)*dt*slope(keys,i+1)
    return float(keys[-1][1])

func yaw_at(tick:int)->int:
    if frozen_profile==0:return super.yaw_at(tick)
    var t:float=Tuning.source_tick(tick,tuning,true)
    return start_yaw+direction*roundi(curve(PROFILES[frozen_profile],t)*65536./360.)

static func sample_keys(keys:Array,t:float)->float:
    for i in range(keys.size()-1):
        if t<=float(keys[i+1][0]):
            return lerpf(float(keys[i][1]),float(keys[i+1][1]),smoothstep(float(keys[i][0]),float(keys[i+1][0]),t))
    return float(keys[-1][1])

func evaluate_target(authored:Dictionary,yaw:int,next:int)->void:
    if frozen_profile==0:
        super.evaluate_target(authored,yaw,next)
        return
    var t:float=Tuning.source_tick(next,tuning,true)
    var gain:float=[0.,.65,1.,1.40][frozen_profile]
    # Pelvis leads the reversal, torso and shoulders retain wind-up then
    # catch up after contact. These relative twists are authored separately.
    var chest:float=sample_keys([[0.,0.],[8.,-8.],[11.,-22.],[13.,-12.],[16.,9.],[21.,16.],[29.,-4.],[36.,0.]],t)*gain
    var shoulder:float=sample_keys([[0.,0.],[9.,-10.],[12.,-17.],[14.,-5.],[18.,13.],[23.,7.],[30.,-3.],[36.,0.]],t)*gain
    var side:String=Support.SIDES[striking]
    # Swing leg steers into the arc, neutral at the authored impact.
    # No per-frame joint length changes; support knee is still solved by IK.
    var leg:float=sample_keys([[0.,0.],[8.,-10.],[10.,-13.],[13.,0.],[17.,18.],[21.,10.],[29.,0.],[36.,0.]],t)*gain
    var azimuth:Dictionary={"thigh_"+side:direction*roundi(leg*65536./360.)}
    # Subtle opposing arm action (not hard mirrored screen positions).
    for s in Support.SIDES:
        var sign_side:float=1. if s==side else -1.
        var arm:float=sample_keys([[0.,0.],[9.,-8.],[13.,9.],[17.,18.],[24.,-5.],[36.,0.]],t)*gain*sign_side
        azimuth["shoulder_"+s]=direction*roundi(arm*65536./360.)
    desired.evaluate_spatial(authored,yaw,0.,direction*roundi(chest*65536./360.),direction*roundi(shoulder*65536./360.),azimuth,true)

func adjust_supported_target(next:int)->void:
    if frozen_profile==0:return
    var t:float=Tuning.source_tick(next,tuning,true)
    var gain:float=[0.,.65,1.,1.25][frozen_profile]
    var hips:Vector3=desired.point3("hips")
    var towards:Vector3=anchor_xyz-hips
    towards.y=0.
    # Small horizontal root bias toward the toe, peak around chamber and
    # impact, release by landing. The existing solver retains the anchor.
    # This is a kinematic weight-transfer cue, not a balance/mass model.
    var weight:float=sample_keys([[0.,0.],[7.,.65],[10.,1.],[13.,.8],[18.,.55],[26.,.25],[36.,0.]],t)*gain
    var shift:Vector3=towards.normalized()*minf(towards.length()*.16,1.35)*weight
    for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+shift
    Entry.update_xy(desired)

func checkpoint()->Dictionary:
    var state:Dictionary=super.checkpoint()
    state["profile"]=profile
    state["frozen_profile"]=frozen_profile
    return state

func load_checkpoint(s:Dictionary)->void:
    super.load_checkpoint(s)
    profile=int(s.get("profile",0))
    frozen_profile=int(s.get("frozen_profile",0))
