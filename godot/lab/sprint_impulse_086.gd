extends RefCounted
## 086: compare both 085 profiles with explicitly phased lift and push-off.
## Pure phase -> pose mapping, fixed 60Hz or fractional sampling.
## Existing 083 C is the control; all geometry uses 069 C.
const Old=preload("res://lab/sprint_profiles_085.gd")
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
    return 1.55 if variant==3 else NEW_SPEED

static func duty_for(variant:int)->float:
    return .34 if variant<2 else .30

static func foot_path(phase:float,variant:int)->Dictionary:
    if variant%2==0:return Old.foot_path(phase,1 if variant==0 else 2)
    var u:float=fposmod(phase,1.)
    var duty:float=duty_for(variant)
    var speed:float=speed_for(variant)
    var half:float=speed*PERIOD*duty*.5
    var center:float=0.
    var lift:float=8. if variant==1 else 10.
    if u<duty:
        var a:float=u/duty
        return {"toe":Vector2(center+half*(1.-2.*a),0.),"pitch":12.-8.*smoothstep(0.,.3,a)+56.*smoothstep(.52,1.,a),"stance":true}
    var s:float=(u-duty)/(1.-duty)
    var x:float=center-half+2.*half*smoothstep(0.,1.,s)-speed*PERIOD*(1.-duty)*s*(1.-s)*(1.-2.*s)
    # Lift earlier in swing, reach forward and decelerate into contact.
    var z:float=s+.18*sin(PI*s)
    var y:float=-lift*pow(sin(PI*z),2.)
    var pitch:float=60.+35.*smoothstep(0.,.27,s)-83.*smoothstep(.33,1.,s)
    return {"toe":Vector2(x,y),"pitch":pitch,"stance":false}

# Periodic nonuniform Hermite root path: touchdown, load, toe-off,
# flight apex, next touchdown. Tangents agree at cycle seam.
static func tangent(a:float,b:float)->float:
    return 0. if a*b<=0. else 2.*a*b/(a+b)

static func height_at(phase:float,variant:int)->float:
    var duty:float=duty_for(variant)
    var ts:Array=[0.,.105,duty,(duty+.5)*.5,.5]
    var contact:float=1.2 if variant==1 else .6
    var ys:Array=[contact,1.8,-.5,-.75 if variant==1 else -1.,contact]
    var t:float=fposmod(phase,.5)
    var i:int=0
    while i<3 and t>float(ts[i+1]):i+=1
    var h:float=float(ts[i+1])-float(ts[i])
    var u:float=(t-float(ts[i]))/h
    var b:float=ys[i]
    var c:float=ys[i+1]
    var v:float=(c-b)/h
    var m0:float=tangent((b-float(ys[i-1]))/(float(ts[i])-float(ts[i-1])),v) if i>0 else tangent((contact-float(ys[3]))/(.5-float(ts[3])),v)
    var m1:float=tangent(v,(float(ys[i+2])-c)/(float(ts[i+2])-float(ts[i+1]))) if i<3 else tangent(v,(float(ys[1])-contact)/.105)
    return (2.*u*u*u-3.*u*u+1.)*b+(u*u*u-2.*u*u+u)*h*m0+(-2.*u*u*u+3.*u*u)*c+(u*u*u-u*u)*h*m1

func sample(t:float,variant:int)->Dictionary:
    if variant%2==0:return old.sample(t,1 if variant==0 else 2)
    var phase:float=fposmod(t,float(PERIOD))/PERIOD
    var p:Dictionary=template.duplicate(true)
    # Whole-body phase design: compress during load (~.12), rise toward
    # toe-off/flight (~.37); body line is taller than the 083 crouch.
    p.root=[0.,height_at(phase,variant)]
    p.angles.hips=(20. if variant==1 else 42.)+2.*sin(4.*PI*phase)
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
