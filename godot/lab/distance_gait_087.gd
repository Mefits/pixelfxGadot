extends RefCounted
## 087: distance-scheduled locomotion. One future alternating step is
## committed before swing; fixed world toe during stance, no frame holds.
## Rig is scratch state. The scheduler is independent of rendering/time.
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const WALK_SPEED:float=1.
const RUN_SPEED:float=1.85
const WALK_STEP:float=16.
const RUN_STEP:float=38.85
const STANCE_DISTANCE:float=18.24
const CENTER:float=.5
const MAX_DROP:float=2.
var rig
var template:Dictionary
var travel:float=0.
var velocity:float=1.
var side:int=0
var queue:Array=[]
var legs:Array=[]

func _init(r,c:Dictionary,start_speed:float=1.):
    rig=r
    template=c.keys[0].pose.duplicate(true)
    velocity=clampf(start_speed,WALK_SPEED,RUN_SPEED)
    var length:float=step_for(velocity)
    queue=[0.,length,2.*length]
    legs=[{"start":0.,"end":2.*length},{"start":-length,"end":length}]

static func gait_for(speed:float)->float:
    return clampf((speed-WALK_SPEED)/(RUN_SPEED-WALK_SPEED),0.,1.)

static func step_for(speed:float)->float:
    return lerpf(WALK_STEP,RUN_STEP,gait_for(speed))

func snapshot()->Dictionary:
    return {"travel":travel,"velocity":velocity,"side":side,"queue":queue.duplicate(true),"legs":legs.duplicate(true)}

func restore(s:Dictionary)->void:
    travel=float(s.travel)
    velocity=float(s.velocity)
    side=int(s.side)
    queue=s.queue.duplicate(true)
    legs=s.legs.duplicate(true)

func advance(speed:float)->void:
    velocity=clampf(speed,WALK_SPEED,RUN_SPEED)
    travel+=velocity
    while travel>=float(queue[1]):
        queue.pop_front()
        queue.append(float(queue[1])+step_for(velocity))
        side=1-side
        legs[side]={"start":queue[0],"end":queue[2]}

func path_for(index:int,w:float)->Dictionary:
    var leg:Dictionary=legs[index]
    var distance:float=travel-float(leg.start)
    var cycle:float=float(leg.end)-float(leg.start)
    var half:float=STANCE_DISTANCE*.5
    if distance<STANCE_DISTANCE:
        var a:float=distance/STANCE_DISTANCE
        var walk_pitch:float=-8.+8.*smoothstep(0.,.3,a)+36.*smoothstep(.65,1.,a)
        var run_pitch:float=12.-8.*smoothstep(0.,.3,a)+56.*smoothstep(.52,1.,a)
        return {"toe":Vector2(CENTER+half-distance,0.),"pitch":lerpf(walk_pitch,run_pitch,w),"stance":true,"start":leg.start}
    var swing:float=cycle-STANCE_DISTANCE
    var s:float=clampf((distance-STANCE_DISTANCE)/swing,0.,1.)
    # Exact same derivative -1 in local X per distance travelled at
    # release and touchdown, with zero vertical derivative at both ends.
    var x:float=CENTER-half+STANCE_DISTANCE*smoothstep(0.,1.,s)-swing*s*(1.-s)*(1.-2.*s)
    var z:float=s+.18*sin(PI*s)
    var y:float=-lerpf(3.,9.,w)*pow(sin(PI*z),2.)
    var walk_pitch:float=36.+12.*smoothstep(0.,.27,s)-56.*smoothstep(.33,1.,s)
    var run_pitch:float=60.+35.*smoothstep(0.,.27,s)-83.*smoothstep(.33,1.,s)
    return {"toe":Vector2(x,y),"pitch":lerpf(walk_pitch,run_pitch,w),"stance":false,"start":leg.start}

func sample()->Dictionary:
    var w:float=gait_for(velocity)
    var f:float=(travel-float(queue[0]))/(float(queue[1])-float(queue[0]))
    var phase:float=float(side)*.5+.5*f
    var p:Dictionary=template.duplicate(true)
    p.root=[0.,lerpf(.6,1.4,w)+lerpf(.6,1.,w)*cos(4.*PI*(phase-.1*w))]
    p.angles.hips=lerpf(10.,38.,w)+2.*sin(4.*PI*phase)
    p.angles.chest=lerpf(3.,6.,w)+2.*cos(4.*PI*phase)
    p.angles.head=lerpf(5.,15.,w)-float(p.angles.hips)-float(p.angles.chest)
    p.angles.pelvis_turn=45.+8.*sin(TAU*phase)
    p.angles.shoulder_turn=lerpf(45.,35.,w)-lerpf(12.,5.,w)*sin(TAU*phase)
    var paths:Dictionary={}
    var goals:Dictionary={}
    for index in 2:
        var name:String=Leg.SIDES[index]
        var u:float=phase+.5*index
        # Fast purposeful walk, then trailing-arm stylized sprint.
        var upper:float=lerpf(-6.+30.*cos(TAU*u),82.+9.*cos(TAU*u+.4),w)
        var elbow:float=lerpf(-60.+12.*cos(TAU*u+.45),-12.+8.*sin(TAU*u),w)
        var a:Vector2=rig.joints[rig.ids["elbow_"+name]].offset
        var b:Vector2=rig.joints[rig.ids["hand_"+name]].offset
        var rest_a:float=rad_to_deg(a.angle())-90.
        var rest_b:float=rad_to_deg(b.angle())-90.
        p.angles["shoulder_"+name]=upper-float(p.angles.hips)-float(p.angles.chest)-rest_a
        p.angles["elbow_"+name]=elbow+rest_a-rest_b
        var path:Dictionary=path_for(index,w)
        p.angles["foot_pitch_"+name]=path.pitch
        paths[name]=path
        goals[name]=Vector2(path.toe)-IK.toe_vector(p,name)
    # Analytic minimal vertical adjustment to reach both targets. This is
    # a kinematic safeguard, not simulated mass or ground reaction force.
    rig.evaluate(p)
    var drop:float=0.
    for name in Leg.SIDES:
        var delta:Vector2=Vector2(goals[name])-rig.point("thigh_"+name)
        var radius:float=IK.reach(rig,name)-.15
        var down:float=sqrt(maxf(0.,radius*radius-delta.x*delta.x))
        drop=maxf(drop,delta.y-down)
    drop=clampf(drop,0.,MAX_DROP)
    p.root[1]=float(p.root[1])+drop
    var error:float=0.
    for name in Leg.SIDES:
        IK.solve_leg(rig,p,name,goals[name],1.)
        rig.evaluate(p)
        var toe:Vector2=rig.point("foot_"+name)+IK.toe_vector(p,name)
        error=maxf(error,toe.distance_to(paths[name].toe))
    return {"pose":p,"goals":paths,"error":error,"drop":drop,"phase":phase,"step_distance":float(queue[1])-float(queue[0]),"gait":w}
