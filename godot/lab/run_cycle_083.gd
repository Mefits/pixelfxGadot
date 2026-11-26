extends RefCounted
## 083: compare held source, cyclic C1 interpolation, and procedural foot path.
## 36 ticks per stride, two alternating stances. No dynamic balance or collisions.
const Clips=preload("res://addons/creature/clips.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const PERIOD:int=36
const KNOTS:int=12
const SPEED:float=1.05
const DUTY:float=.42
const LIFT:float=5.5
var knots:Array=[]
var source:Dictionary
var rig

func _init(r,c:Dictionary):
    rig=r
    source=c
    for i in KNOTS:
        knots.append(c.keys[i*3].pose.duplicate(true))

static func tangent(a:float,b:float)->float:
    if a*b<=0.:return 0.
    return 2.*a*b/(a+b)

static func curve(a:float,b:float,c:float,d:float,u:float)->float:
    var m0:float=tangent(b-a,c-b)
    var m1:float=tangent(c-b,d-c)
    return (2.*u*u*u-3.*u*u+1.)*b+(u*u*u-2.*u*u+u)*m0+(-2.*u*u*u+3.*u*u)*c+(u*u*u-u*u)*m1

static func angle_curve(a:float,b:float,c:float,d:float,u:float)->float:
    var aa:float=b+wrapf(a-b,-180.,180.)
    var cc:float=b+wrapf(c-b,-180.,180.)
    var dd:float=cc+wrapf(d-c,-180.,180.)
    return curve(aa,b,cc,dd,u)

func smooth_pose(t:float)->Dictionary:
    var f:float=fposmod(t,float(PERIOD))/3.
    var i:int=floori(f)
    var u:float=f-i
    var a:Dictionary=knots[posmod(i-1,KNOTS)]
    var b:Dictionary=knots[i]
    var c:Dictionary=knots[posmod(i+1,KNOTS)]
    var d:Dictionary=knots[posmod(i+2,KNOTS)]
    var p:Dictionary=b.duplicate(true)
    for id in b.angles:
        p.angles[id]=angle_curve(a.angles[id],b.angles[id],c.angles[id],d.angles[id],u)
    for axis in 2:p.root[axis]=curve(a.root[axis],b.root[axis],c.root[axis],d.root[axis],u)
    for side in Leg.SIDES:
        var bend:float=curve(maxf(0.,Leg.bend(a,side)),maxf(0.,Leg.bend(b,side)),maxf(0.,Leg.bend(c,side)),maxf(0.,Leg.bend(d,side)),u)
        var ankle:float=curve(Leg.ankle(a,side),Leg.ankle(b,side),Leg.ankle(c,side),Leg.ankle(d,side),u)
        Leg.put(p,side,bend,ankle)
    return p

static func foot_path(phase:float)->Dictionary:
    var u:float=fposmod(phase,1.)
    var half:float=SPEED*PERIOD*DUTY*.5
    if u<DUTY:
        var a:float=u/DUTY
        return {"toe":Vector2(4.+half*(1.-2.*a),0.),"pitch":-8.+8.*smoothstep(0.,.3,a)+45.*smoothstep(.65,1.,a),"stance":true}
    var s:float=(u-DUTY)/(1.-DUTY)
    # Hermite endpoints have the same backward velocity as stance.
    # A sin² clearance arc has zero vertical velocity at both contacts.
    var x:float=4.-half+2.*half*smoothstep(0.,1.,s)-SPEED*PERIOD*(1.-DUTY)*s*(1.-s)*(1.-2.*s)
    var y:float=-LIFT*pow(sin(PI*s),2.)
    var pitch:float=45.+50.*smoothstep(0.,.35,s)-103.*smoothstep(.4,1.,s)
    return {"toe":Vector2(x,y),"pitch":pitch,"stance":false}

func sample(t:float,variant:int)->Dictionary:
    var p:Dictionary=Clips.sample(source,fposmod(t,float(PERIOD))/60.,false) if variant==0 else smooth_pose(t)
    var goals:Dictionary={}
    var max_error:float=0.
    if variant==2:
        var phase:float=fposmod(t,float(PERIOD))/PERIOD
        # Keep the existing forward-leaning sprint silhouette and arm keys.
        # Small continuous body compression at mid-stance, extension in flight.
        p.root=[0.,4.4+1.3*cos(4.*PI*(phase-.21))]
        p.angles.hips=54.+2.*sin(4.*PI*phase)
        for side in Leg.SIDES:
            var path:Dictionary=foot_path(phase+(.5 if side=="far" else 0.))
            p.angles["foot_pitch_"+side]=path.pitch
            var goal:Vector2=Vector2(path.toe)-IK.toe_vector(p,side)
            IK.solve_leg(rig,p,side,goal,1.)
            rig.evaluate(p)
            var toe:Vector2=rig.point("foot_"+side)+IK.toe_vector(p,side)
            max_error=maxf(max_error,toe.distance_to(path.toe))
            goals[side]=path
    return {"pose":p,"goals":goals,"error":max_error}
