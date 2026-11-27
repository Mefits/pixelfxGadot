extends RefCounted
const Motion=preload("res://lab/walk_motion.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Support=preload("res://lab/hybrid091/support.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const LIMIT:float=48.
const FACING:int=1
const STOP_TICKS:int=16
const START_TICKS:int=10
var rig=Body.make_rig()
var support=Support.new(rig)
var programs:Dictionary={}
var x:float=0.
var phase:float=0.
var activity:float=0.
var direction:int=0
var pose:Dictionary={}
var paths:Array=[]
var ticks:int=0
var transition_age:int=0
var transition_from:Dictionary={}
var transition_toes:Array=[]
var transition_pitch:Array=[]
var transition_x:float=0.
var first_foot:int=0

func _init(overrides:Dictionary={}):
    for id in ["walk_idle","walk_forward","walk_backward"]:
        programs[id]=Motion.prepare(overrides.get(id,Motion.document(id)))
    set_intent(Motion.intent(programs.walk_idle,0.,rig))

func set_intent(value:Dictionary)->void:
    paths=value.paths
    pose=Motion.resolve(rig,support,value)

func capture_transition()->void:
    transition_age=0
    transition_from=pose.duplicate(true)
    transition_toes=Motion.toes(rig,pose)
    transition_pitch=[pose.angles.foot_pitch_near,pose.angles.foot_pitch_far]
    transition_x=x
    first_foot=0 if not paths[0].stance else (1 if not paths[1].stance else 0)

func choose_phase(program:Dictionary)->float:
    var best:float=INF
    var result:float=0.
    for i in 32:
        var u:float=float(i)/32.
        var value:Dictionary=Motion.intent(program,u,rig)
        var score:float=0.
        for side in 2:score+=Vector2(value.paths[side].toe).distance_squared_to(transition_toes[side])
        if score<best:
            best=score
            result=u
    return result

func step(command:int)->void:
    var requested:int=clampi(command,-1,1)
    if (x>=LIMIT and requested>0) or (x<=-LIMIT and requested<0):requested=0
    if requested!=direction:
        capture_transition()
        direction=requested
        if direction!=0:phase=choose_phase(programs[action_name()])
    ticks+=1
    transition_age+=1
    if direction==0:
        stop_step()
        return
    var program:Dictionary=programs[action_name()]
    var distance:float=Motion.STRIDE/(float(program.doc.duration)*60.)
    var next:float=clampf(x+direction*distance,-LIMIT,LIMIT)
    phase=fposmod(phase+absf(next-x)/Motion.STRIDE,1.)
    x=next
    var value:Dictionary=Motion.intent(program,phase,rig)
    activity=minf(1.,float(transition_age)/START_TICKS)
    if transition_age<START_TICKS and not transition_from.is_empty():
        var u:float=smoothstep(0.,float(START_TICKS),float(transition_age))
        value.pose=Clips.blend_pose(transition_from,value.pose,u)
        for i in 2:
            var old:Vector2=transition_toes[i]+Vector2.RIGHT*(transition_x-x)
            value.paths[i].toe=Grid.point(old.lerp(value.paths[i].toe,u))
            value.paths[i].pitch=Grid.scalar(lerpf(transition_pitch[i],value.paths[i].pitch,u))
            value.paths[i].stance=false
    set_intent(value)

func stop_step()->void:
    var value:Dictionary=Motion.intent(programs.walk_idle,0.,rig)
    if transition_from.is_empty() or transition_age>=STOP_TICKS:
        activity=0.
        set_intent(value)
        return
    var u:float=clampf(float(transition_age)/STOP_TICKS,0.,1.)
    activity=1.-u
    value.pose=Clips.blend_pose(transition_from,value.pose,smoothstep(0.,1.,u))
    for i in 2:
        var order:int=0 if i==first_foot else 1
        var k:float=clampf(u*2.-order,0.,1.)
        var goal:Vector2=value.paths[i].toe
        var old:Vector2=transition_toes[i]+Vector2.RIGHT*(transition_x-x)
        var point:Vector2=old.lerp(goal,smoothstep(0.,1.,k))
        if old.distance_to(goal)>.1:point.y-=1.6*pow(sin(PI*k),2.)
        value.paths[i].toe=Grid.point(point)
        value.paths[i].pitch=Grid.scalar(lerpf(transition_pitch[i],value.paths[i].pitch,smoothstep(0.,1.,k)))
        value.paths[i].stance=k==0. or k==1.
    set_intent(value)

func action_name()->String:
    return "walk_forward" if direction>0 else ("walk_backward" if direction<0 else "walk_idle")
