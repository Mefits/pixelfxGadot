extends RefCounted
## Lab 084: authored kick comparison, not a new runtime controller.
const Clips=preload("res://addons/creature/clips.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const TIMES=[38.,42.,45.,50.,55.,59.,64.,76.]
var rig
var source:Dictionary
var poses:Array=[]
var roots:Array=[]
var toes:Array=[]
var pitches:Array=[]
var support:Vector2

func _init(r,c:Dictionary):
    rig=r
    source=c
    for t in TIMES:
        var p:Dictionary=Clips.sample(source,t/60.,false)
        poses.append(p)
        roots.append(Vector2(float(p.root[0]),float(p.root[1])))
        rig.evaluate(p)
        toes.append(rig.point("foot_far")+IK.toe_vector(p,"far"))
        pitches.append(float(p.angles.foot_pitch_far))
    rig.evaluate(poses[0])
    support=rig.point("foot_near")+IK.toe_vector(poses[0],"near")
    # Redesigned loading and chamber path. Keep the incoming pose, strike
    # pose and terminal pose, but do not copy the old rapid root projection.
    roots[1]=Vector2(7.,1.8)
    roots[2]=Vector2(10.4,.5)
    roots[4]=Vector2(11.,-.4)
    roots[5]=Vector2(8.4,.5)
    roots[6]=Vector2(roots[6])+Vector2(0.,.2)
    toes[1]=Vector2(2.,-7.)
    toes[2]=Vector2(17.,-16.)
    toes[4]=Vector2(25.,-22.)
    toes[5]=Vector2(18.,-14.)
    pitches[1]=5.
    pitches[2]=0.
    pitches[4]=-35.
    pitches[5]=-15.

static func tangent(a:float,b:float)->float:
    return 0. if a*b<=0. else 2.*a*b/(a+b)

static func interp(t:float,values:Array,angular:bool=false)->float:
    if t<=TIMES[0]:return float(values[0])
    if t>=TIMES[-1]:return float(values[-1])
    var i:int=0
    while i<TIMES.size()-2 and t>float(TIMES[i+1]):i+=1
    var h:float=float(TIMES[i+1])-float(TIMES[i])
    var u:float=(t-float(TIMES[i]))/h
    var b:float=values[i]
    var c:float=values[i+1]
    var a:float=values[maxi(0,i-1)]
    var d:float=values[mini(TIMES.size()-1,i+2)]
    if angular:
        a=b+wrapf(a-b,-180.,180.)
        c=b+wrapf(c-b,-180.,180.)
        d=c+wrapf(float(values[mini(TIMES.size()-1,i+2)])-float(values[i+1]),-180.,180.)
    var v:float=(c-b)/h
    var m0:float=tangent((b-a)/(float(TIMES[i])-float(TIMES[i-1])),v) if i>0 else 0.
    var m1:float=tangent(v,(d-c)/(float(TIMES[i+2])-float(TIMES[i+1]))) if i+2<TIMES.size() else 0.
    return (2.*u*u*u-3.*u*u+1.)*b+(u*u*u-2.*u*u+u)*h*m0+(-2.*u*u*u+3.*u*u)*c+(u*u*u-u*u)*h*m1

func vector_curve(t:float,values:Array)->Vector2:
    var x:Array=[]
    var y:Array=[]
    for v in values:
        x.append(Vector2(v).x)
        y.append(Vector2(v).y)
    return Vector2(interp(t,x),interp(t,y))

func smooth_pose(t:float)->Dictionary:
    var p:Dictionary=poses[0].duplicate(true)
    for id in p.angles:
        var values:Array=[]
        for q in poses:values.append(float(q.angles[id]))
        p.angles[id]=interp(t,values,true)
    var root_values:Array=[]
    for q in poses:root_values.append(Vector2(float(q.root[0]),float(q.root[1])))
    var root:Vector2=vector_curve(t,root_values)
    p.root=[root.x,root.y]
    for side in Leg.SIDES:
        var bends:Array=[]
        var ankles:Array=[]
        for q in poses:
            bends.append(Leg.bend(q,side))
            ankles.append(Leg.ankle(q,side))
        Leg.put(p,side,interp(t,bends),interp(t,ankles))
    return p

func sample(t:float,variant:int)->Dictionary:
    var time:float=clampf(t,0.,76.)
    var p:Dictionary=Clips.sample(source,time/60.,false)
    var error:float=0.
    # Exact endpoints and original strike marker. No changes to punches.
    if variant==0 or time<=38. or time>=76. or is_equal_approx(time,50.):
        return {"pose":p,"error":error}
    p=smooth_pose(time)
    if variant==2:
        var root:Vector2=vector_curve(time,roots)
        p.root=[root.x,root.y]
        p.angles.foot_pitch_far=interp(time,pitches,true)
        var goals:Dictionary={"near":support,"far":vector_curve(time,toes)}
        for side in Leg.SIDES:
            var goal:Vector2=Vector2(goals[side])-IK.toe_vector(p,side)
            IK.solve_leg(rig,p,side,goal,1.)
            rig.evaluate(p)
            var toe:Vector2=rig.point("foot_"+side)+IK.toe_vector(p,side)
            error=maxf(error,toe.distance_to(goals[side]))
    return {"pose":p,"error":error}
