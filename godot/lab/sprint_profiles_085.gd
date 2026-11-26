extends RefCounted
## 085: whole-body phase profiles, manual art direction (not mocap).
## Pure phase -> pose mapping, fixed 60Hz or fractional sampling.
## Existing 083 C is the control; all geometry uses 069 C.
const Old=preload("res://lab/run_cycle_083.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const PERIOD:int=36
const NEW_SPEED:float=1.45
var rig
var old
var template:Dictionary

func _init(r,c:Dictionary):
    rig=r
    old=Old.new(r,c)
    template=c.keys[0].pose.duplicate(true)

static func speed_for(variant:int)->float:
    return Old.SPEED if variant==0 else NEW_SPEED

static func duty_for(variant:int)->float:
    if variant==0:return Old.DUTY
    return .34 if variant==1 else .30

static func foot_path(phase:float,variant:int)->Dictionary:
    if variant==0:return Old.foot_path(phase)
    var u:float=fposmod(phase,1.)
    var duty:float=duty_for(variant)
    var half:float=NEW_SPEED*PERIOD*duty*.5
    var center:float=0. if variant==1 else 3.
    var lift:float=6.5 if variant==1 else 7.5
    if u<duty:
        var a:float=u/duty
        return {"toe":Vector2(center+half*(1.-2.*a),0.),"pitch":12.-8.*smoothstep(0.,.3,a)+56.*smoothstep(.52,1.,a),"stance":true}
    var s:float=(u-duty)/(1.-duty)
    var x:float=center-half+2.*half*smoothstep(0.,1.,s)-NEW_SPEED*PERIOD*(1.-duty)*s*(1.-s)*(1.-2.*s)
    # Lift earlier in swing, reach forward and decelerate into contact.
    var z:float=s+.15*sin(PI*s)
    var y:float=-lift*pow(sin(PI*z),2.)
    var pitch:float=60.+35.*smoothstep(0.,.27,s)-83.*smoothstep(.33,1.,s)
    return {"toe":Vector2(x,y),"pitch":pitch,"stance":false}

func sample(t:float,variant:int)->Dictionary:
    if variant==0:return old.sample(t,2)
    var phase:float=fposmod(t,float(PERIOD))/PERIOD
    var p:Dictionary=template.duplicate(true)
    # Whole-body phase design: compress during load (~.12), rise toward
    # toe-off/flight (~.37); body line is taller than the 083 crouch.
    var amplitude:float=1.3 if variant==1 else .7
    p.root=[0.,.6+amplitude*cos(4.*PI*(phase-.12))]
    p.angles.hips=(17. if variant==1 else 39.)+2.*sin(4.*PI*phase)
    p.angles.chest=(3. if variant==1 else 6.)+2.*cos(4.*PI*phase)
    p.angles.head=(5. if variant==1 else 15.)-float(p.angles.hips)-float(p.angles.chest)
    p.angles.pelvis_turn=45.+8.*sin(TAU*phase)
    p.angles.shoulder_turn=(45. if variant==1 else 35.)- (12. if variant==1 else 5.)*sin(TAU*phase)
    var goals:Dictionary={}
    var error:float=0.
    for side in Leg.SIDES:
        var u:float=phase+(.5 if side=="far" else 0.)
        # Explicit silhouette profiles in global arm-line angles relative
        # to downward vertical. Sport: opposite-leg arm swing. Anime:
        # both arms trail, with a small secondary pulse instead of frozen.
        var upper:float=0.
        var elbow:float=0.
        if variant==1:
            upper=-6.+42.*cos(TAU*u)
            elbow=-82.+12.*cos(TAU*u+.45)
        else:
            upper=82.+9.*cos(TAU*u+.4)
            elbow=-12.+8.*sin(TAU*u)
        var upper_offset:Vector2=rig.joints[rig.ids["elbow_"+side]].offset
        var lower_offset:Vector2=rig.joints[rig.ids["hand_"+side]].offset
        var upper_rest:float=rad_to_deg(upper_offset.angle())-90.
        var lower_rest:float=rad_to_deg(lower_offset.angle())-90.
        p.angles["shoulder_"+side]=upper-float(p.angles.hips)-float(p.angles.chest)-upper_rest
        p.angles["elbow_"+side]=elbow+upper_rest-lower_rest
        var path:Dictionary=foot_path(u,variant)
        p.angles["foot_pitch_"+side]=path.pitch
        var goal:Vector2=Vector2(path.toe)-IK.toe_vector(p,side)
        IK.solve_leg(rig,p,side,goal,1.)
        rig.evaluate(p)
        var toe:Vector2=rig.point("foot_"+side)+IK.toe_vector(p,side)
        error=maxf(error,toe.distance_to(path.toe))
        goals[side]=path
    return {"pose":p,"goals":goals,"error":error}
