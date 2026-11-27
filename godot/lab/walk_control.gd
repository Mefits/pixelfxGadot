extends RefCounted
const Asset=preload("res://lab/authoring/asset.gd")
const RunBase=preload("res://lab/distance_gait_087.gd")
const RunGait=preload("res://lab/hybrid091/gait.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Profile=preload("res://lab/fighter_profile.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Support=preload("res://lab/hybrid091/support.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const LIMIT:float=48.
const FACING:int=1
const STOP_TICKS:int=16
const START_TICKS:int=10
const LEAD_DEADBAND:float=.6
const RUN_SPEED:float=111. # rig units / s, existing 091 sprint speed
const RUN_ACCEL:float=300.
const RUN_BRAKE:float=420.
const RUN_BLEND_TICKS:int=8
var ground_speed:float=0.
var sprint_active:bool=false
var run_gait

var profile:Dictionary
var rig
var support
var programs:Dictionary={}
var travel_limit:float=LIMIT # T can enlarge its arena without changing other callers.
var x:float=0.
var phase:float=0.
var activity:float=0.
var direction:int=0
var pose:Dictionary={}
var paths:Array=[]
var ticks:int=0
var transition_age:int=0
var idle_ticks:int=0
var idle_active:bool=false
var support_load:Array=[.5,.5]
var transition_from:Dictionary={}
var transition_toes:Array=[]
var transition_pitch:Array=[]
var transition_x:float=0.
var first_foot:int=0
# Index of the foot in front (larger x; facing stays right).
var guard_lead:int=0

func _init(overrides:Dictionary={},profile_override:Dictionary={}):
    profile=Profile.load_profile(profile_override)
    rig=Profile.make_rig(profile)
    support=Support.new(rig)
    var stance:Dictionary=overrides.get("walk_idle",Motion.document("walk_idle"))
    for id in ["walk_idle","walk_forward","walk_backward"]:
        programs[id]=Motion.prepare(overrides.get(id,Motion.document(id)))
    programs.walk_breathe=Motion.prepare(overrides.get("walk_breathe",Motion.document("walk_breathe")),stance)
    set_intent(Profile.apply_guard(Motion.intent(programs.walk_idle,0.,rig),profile))
    guard_lead=lead_of(Motion.toes(rig,pose),guard_lead)
    idle_active=true

# Preserve the last clear ordering when feet overlap. Never rename near/far.
static func lead_of(points:Array,previous:int)->int:
    var separation:float=Vector2(points[0]).x-Vector2(points[1]).x
    if absf(separation)<=LEAD_DEADBAND:return previous
    return 0 if separation>0. else 1

func guard_intent(program:Dictionary,u:float)->Dictionary:
    var value:Dictionary=Profile.apply_guard(Motion.intent(program,u,rig),profile)
    var canonical:int=0 if Vector2(value.paths[0].toe).x>=Vector2(value.paths[1].toe).x else 1
    if canonical!=guard_lead:
        # Reassign contact goals, not leg bones, angles, depth, or attack data.
        # Support.resolve solves each original leg against its own new goal.
        value.paths.reverse()
        value.support_load.reverse()
    return value

func set_intent(value:Dictionary)->void:
    paths=value.paths
    support_load=value.get("support_load",[.5,.5])
    pose=Motion.resolve(rig,support,value)

# Recenter the locomotion frame at the new support span without translating
# any rendered world joint. The new guard already matches the landed toes.
func rebase_landing(delta:float)->void:
    x+=delta
    pose.root[0]-=delta
    for i in 2:
        paths[i].toe=Vector2(paths[i].toe)-Vector2.RIGHT*delta
    rig.evaluate(pose)
    guard_lead=lead_of(Motion.toes(rig,pose),guard_lead)

func capture_transition()->void:
    transition_age=0
    idle_ticks=0
    idle_active=false
    transition_from=pose.duplicate(true)
    transition_toes=Motion.toes(rig,pose)
    transition_pitch=[pose.angles.foot_pitch_near,pose.angles.foot_pitch_far]
    transition_x=x
    guard_lead=lead_of(transition_toes,guard_lead)
    first_foot=0 if not paths[0].stance else (1 if not paths[1].stance else 0)
    # Prefer the airborne foot, unless that move would cross the other foot.
    # With an unchanged left/right order, one of the two sequences is safe.
    var goal:Dictionary=guard_intent(programs.walk_idle,0.)
    var other:int=1-first_foot
    var first_x:float=Vector2(goal.paths[first_foot].toe).x
    var other_x:float=Vector2(transition_toes[other]).x
    if (first_foot==guard_lead and first_x<other_x) or (first_foot!=guard_lead and first_x>other_x):
        first_foot=other
    rig.evaluate(pose) # Preserve the final animation frame for rendering.

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

# Ordinary authored walking is unchanged. Shift enters the continuous
# distance gait; its signed speed, not an animation frame, drives travel.
func step(command:int,sprint:bool=false,right_limit:float=INF)->void:
    var requested:int=clampi(command,-1,1)
    var right:float=minf(travel_limit,right_limit)
    if (x>=right and requested>0) or (x<=-travel_limit and requested<0):requested=0
    if sprint_active or (sprint and requested!=0):
        if not sprint_active:
            var run_dir:int=1 if ground_speed>0. else (-1 if ground_speed<0. else requested)
            begin_run(run_dir)
        sprint_step(requested,sprint,right)
        return
    var previous:float=x
    walk_step(requested)
    ground_speed=(x-previous)*60.

func walk_speed(dir:int)->float:
    var id:String="walk_forward" if dir>=0 else "walk_backward"
    return Motion.STRIDE/maxf(.01,float(programs[id].doc.duration))

# Actions own the motion until they release it; do not let stale speed leak
# through a stationary punch, a landing, or the next jump.
func suspend_motion()->void:
    ground_speed=0.
    sprint_active=false
    run_gait=null

func run_intent(dir:int)->Dictionary:
    var value:Dictionary=run_gait.intent()
    if dir<0:
        # Backpedal without changing facing or the anatomical near/far IDs.
        # Use the same distance calendar; keep a more defensive upper body.
        for path in value.paths:
            var toe:Vector2=path.toe
            toe.x=-toe.x
            path.toe=toe
            path.pitch=clampf(float(path.pitch),-12.,35.)
        var p:Dictionary=value.pose
        var guard:Dictionary=programs.walk_idle.doc.keys[0]
        p.angles.hips=-lerpf(5.,16.,float(value.gait))
        p.angles.chest=-4.
        p.angles.head=-float(p.angles.hips)-float(p.angles.chest)
        for side in Motion.SIDES:
            for channel in ["shoulder_","elbow_"]:
                var id:String=channel+side
                p.angles[id]=lerpf(float(p.angles[id]),float(guard.angles[id]),.85)
    return value

func begin_run(dir:int)->void:
    capture_transition()
    direction=dir
    sprint_active=true
    var clip:Dictionary=Asset.read(Asset.FIX+"run053a_C.json").payload.clip
    var rate:float=clampf(absf(ground_speed)/60.,1.,1.85)
    run_gait=RunGait.new(rig,clip,rate)
    var length:float=RunBase.step_for(rate)
    var best:float=INF
    var chosen:Dictionary={}
    # Select a nearby phase on entry instead of starting every run with
    # the same foot. The accepted scheduler then commits alternating steps.
    for i in 32:
        var travel:float=float(i)*2.*length/32.
        var side:int=0 if travel<length else 1
        var start:float=side*length
        run_gait.travel=travel
        run_gait.side=side
        run_gait.queue=[start,start+length,start+2.*length]
        run_gait.legs=[{},{}]
        run_gait.legs[side]={"start":start,"end":start+2.*length}
        run_gait.legs[1-side]={"start":start-length,"end":start+length}
        var value:Dictionary=run_intent(dir)
        var score:float=0.
        for j in 2:score+=Vector2(value.paths[j].toe).distance_squared_to(transition_toes[j])
        if score<best:
            best=score
            chosen=run_gait.snapshot()
    run_gait.restore(chosen)
    rig.evaluate(pose)

func sprint_step(requested:int,sprint:bool,right:float)->void:
    ticks+=1
    transition_age+=1
    var same:bool=requested==direction
    var target:float=(RUN_SPEED if sprint else walk_speed(direction)) if same else 0.
    var old:float=absf(ground_speed)
    var rate:float=RUN_ACCEL if target>old else RUN_BRAKE
    var speed:float=move_toward(old,target,rate/60.)
    var next:float=clampf(x+direction*speed/60.,-travel_limit,right)
    var distance:float=absf(next-x)
    var blocked:bool=distance+0.00001<speed/60.
    x=next
    ground_speed=direction*distance*60.
    if distance>.00001:
        run_gait.move_distance(clampf(absf(ground_speed)/60.,1.,1.85),distance)
        var value:Dictionary=run_intent(direction)
        activity=minf(1.,float(transition_age)/RUN_BLEND_TICKS)
        if transition_age<RUN_BLEND_TICKS:
            var u:float=smoothstep(0.,float(RUN_BLEND_TICKS),float(transition_age))
            value.pose=Clips.blend_pose(transition_from,value.pose,u)
            for i in 2:
                var old_toe:Vector2=transition_toes[i]+Vector2.RIGHT*(transition_x-x)
                value.paths[i].toe=Grid.point(old_toe.lerp(value.paths[i].toe,u))
                value.paths[i].pitch=Grid.scalar(lerpf(transition_pitch[i],value.paths[i].pitch,u))
                value.paths[i].stance=false
        set_intent(value)
    if blocked or speed<=.00001:
        suspend_motion()
        capture_transition()
        direction=0
        return
    if same and not sprint and speed<=target+.00001:
        # Match the authored walk at the same velocity and nearest phase.
        sprint_active=false
        run_gait=null
        capture_transition()
        phase=choose_phase(programs[action_name()])

func walk_step(command:int)->void:
    var requested:int=clampi(command,-1,1)
    if (x>=travel_limit and requested>0) or (x<=-travel_limit and requested<0):requested=0
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
    var next:float=clampf(x+direction*distance,-travel_limit,travel_limit)
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
    var value:Dictionary=guard_intent(programs.walk_idle,0.)
    if transition_from.is_empty() or transition_age>=STOP_TICKS:
        activity=0.
        if idle_active or transition_age>STOP_TICKS+2:
            idle_active=true
            idle_ticks+=1
            var program:Dictionary=programs.walk_breathe
            var breath:Dictionary=guard_intent(program,idle_phase())
            # Ease only on entry; after that use the complete continuous intent.
            var mix:float=smoothstep(0.,12.,float(idle_ticks))
            value.pose=Clips.blend_pose(value.pose,breath.pose,mix)
            for i in 2:
                value.paths[i].toe=Grid.point(Vector2(value.paths[i].toe).lerp(breath.paths[i].toe,mix))
                value.paths[i].pitch=Grid.scalar(lerpf(value.paths[i].pitch,breath.paths[i].pitch,mix))
            var load_value:float=lerpf(.5,float(breath.support_load[0]),mix)
            value.support_load=[load_value,1.-load_value]
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
        if absf(old.x-goal.x)>.3:point.y-=.8*pow(sin(PI*k),2.)
        value.paths[i].toe=Grid.point(point)
        value.paths[i].pitch=Grid.scalar(lerpf(transition_pitch[i],value.paths[i].pitch,smoothstep(0.,1.,k)))
        value.paths[i].stance=k==0. or k==1.
    set_intent(value)

func idle_phase()->float:
    return fposmod(float(idle_ticks)/(float(programs.walk_breathe.doc.duration)*60.),1.)

func idle_time()->float:
    return idle_phase()*float(programs.walk_breathe.doc.duration)

func action_name()->String:
    return "walk_forward" if direction>0 else ("walk_backward" if direction<0 else ("walk_breathe" if idle_active else "walk_idle"))
