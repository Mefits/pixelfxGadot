extends "res://lab/impact_reactions_091.gd"
## 092: amplify hybrid accents; optional explicit recovery-step permission.
## No gameplay stun/launch decision inferred from the visual response.
var style:int
var step_age:int=-1
var moving:String=""
var from_ankle:=Vector2.ZERO
var to_ankle:=Vector2.ZERO
var from_root:=Vector2.ZERO
var direction:float=0.
const STEP_TICKS:int=24

func _init(r,p:Dictionary,m:int):
    super(r,p,2)
    style=m

func hit(id:int,zone:String,dir:float,power:float)->bool:
    var previous:Array=v.duplicate()
    if not super.hit(id,zone,dir,power):return false
    if style==0:return true
    # Amplify the local accent, retain spring momentum and the old bounds.
    var gains:Array=[1.10,1.32,1.23,1.15,1.15,1.18,1.18,1.10,1.10]
    for i in CHANNELS.size():
        var cap:float=1000. if i<7 else 75.
        v[i]=clampf(float(previous[i])+(float(v[i])-float(previous[i]))*float(gains[i]),-cap,cap)
        active[-1].target[i]=float(active[-1].target[i])*float(gains[i])
    return true

func permit_recovery_step(dir:float)->bool:
    if style!=2 or step_age>=0 or absf(dir)!=1.:return false
    # A future gameplay policy may grant this permission based on hit
    # category or balance; ordinary hits alone never translate the base.
    direction=dir
    moving="near" if dir*float(anchors.near.x)>dir*float(anchors.far.x) else "far"
    from_ankle=anchors[moving]
    to_ankle=from_ankle+Vector2(4.5*dir,0.)
    from_root=IK.root_of(base)
    step_age=0
    return true

func snapshot()->Dictionary:
    var s:Dictionary=super.snapshot()
    s.merge({"step_age":step_age,"moving":moving,"from_ankle":from_ankle,"to_ankle":to_ankle,"from_root":from_root,"direction":direction,"anchors":anchors.duplicate(true),"base_root":base.root.duplicate()})
    return s

func restore(s:Dictionary)->void:
    super.restore(s)
    step_age=int(s.step_age)
    moving=s.moving
    from_ankle=s.from_ankle
    to_ankle=s.to_ankle
    from_root=s.from_root
    direction=float(s.direction)
    anchors=s.anchors.duplicate(true)
    base.root=s.base_root.duplicate()

func step()->Dictionary:
    var phase:String="HOLD"
    var swing:bool=false
    if step_age>=0:
        var t:float=float(step_age)
        var u:float=clampf((t-3.)/13.,0.,1.)
        var h:float=smoothstep(0.,1.,u)
        anchors[moving]=from_ankle.lerp(to_ankle,h)+Vector2(0.,-3.0*16.*u*u*(1.-u)*(1.-u))
        var progress:float=smoothstep(0.,float(STEP_TICKS),t)
        var root:Vector2=from_root+Vector2(direction*2.1*progress,.6*progress+.8*sin(PI*progress))
        base.root=[root.x,root.y]
        phase="LOAD" if t<=3. else ("STEP" if t<16. else "SETTLE")
        swing=t>3. and t<16.
        if step_age>=STEP_TICKS:step_age=-1
        else:step_age+=1
    var result:Dictionary=super.step()
    result["phase"]=phase
    result["moving"]=moving
    result["swing"]=swing
    result["anchors"]=anchors.duplicate(true)
    return result
