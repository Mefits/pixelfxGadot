extends RefCounted
## One authority at a time; no changes to Astra's solver or Box2D's native solver.
const Common=preload("res://lab/ragdoll_common_099c.gd")
const Controller=preload("res://lab/motionphysics_controller.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const ASTRA=0
const PHYSICS=1
const RECOVERY=2
const RECOVERY_TICKS=48
var player
var physics
var rig
var phase:int=ASTRA
var pose:Dictionary={}
var travel:float=0.
var previous:Dictionary={}
var previous_travel:float=0.
var offset:float=0.
var origin:float=0.
var recovery_age:int=0
var recovery_from:Dictionary={}
var recovery_to:Dictionary={}
var recovery_travel:float=0.
var quiet_ticks:int=0
var return_requested:bool=false
var entry_error:float=0.
var velocity_error:float=0.
var velocity_clamps:int=0
var message:String=""
var floor_y:float=0.

func _init(kernel):
    player=kernel
    rig=Body.make_rig()
    physics=Controller.new()
    pose=player.final_pose.duplicate(true)
    travel=player.gait.travel
    previous=pose.duplicate(true)
    previous_travel=travel
    rig.evaluate(pose)

func world_pose(p:Dictionary,x:float)->Dictionary:
    var q:Dictionary=p.duplicate(true)
    q.root[0]=float(q.root[0])+x
    return q

func points(p:Dictionary,x:float)->Dictionary:
    rig.evaluate(world_pose(p,x))
    return rig.points.duplicate()

# Build native bodies from the *actual* last two resolved FK samples, including
# projected shoulder/pelvis offsets and horizontal locomotion. Freeze the
# projected girdle geometry for the duration of this planar physical episode.
func entry_model():
    var m=Common.make_model()
    var a:Dictionary=world_pose(previous,previous_travel-travel)
    var b:Dictionary=pose.duplicate(true)
    m.rig.evaluate(a)
    var old_points:Dictionary=m.rig.points.duplicate()
    var old_angles:Dictionary=m.rig.rotations.duplicate()
    m.rig.evaluate(b)
    m.template=b.duplicate(true)
    velocity_clamps=0
    for i in m.bodies.size():
        var segment:Dictionary=m.bodies[i]
        var id:String=segment.id
        var ang:float=m.rotation_for(id,b,m.rig.rotations)
        var old_ang:float=m.rotation_for(id,a,old_angles)
        var pos:Vector2=m.rig.point(id)+Vector2(segment.com).rotated(ang)
        var old_pos:Vector2=Vector2(old_points[id])+Vector2(segment.com).rotated(old_ang)
        var v:Vector2=(pos-old_pos)*60.
        var w:float=wrapf(ang-old_ang,-PI,PI)*60.
        if v.length()>999. or absf(w)>99.:velocity_clamps+=1
        segment.p=pos
        segment.a=ang
        segment.v=v.limit_length(999.)
        segment.w=clampf(w,-99.,99.)
        segment.offset=Vector2(m.rig.joints[m.rig.ids[id]].offset)
        # A valid authored entry may exceed the narrower experimental pike
        # bounds. Admit that entry angle without discontinuous projection.
        if int(segment.parent)>=0:
            var parent:Dictionary=m.bodies[segment.parent]
            var relative:float=wrapf(ang-float(parent.a),-PI,PI)
            segment.lo=maxf(-.99*PI,minf(float(segment.lo),relative))
            segment.hi=minf(.99*PI,maxf(float(segment.hi),relative))
            segment.goal=clampf(float(segment.goal),segment.lo,segment.hi)
    return m

func hit(id:String="hips",direction:Vector2=Vector2.LEFT,power:float=1.,profile:int=1)->bool:
    if phase==RECOVERY:
        message="Повторный удар во время подъёма пока не поддержан"
        return false
    if profile<0 or profile>2:return false
    if phase==PHYSICS:
        if not physics.hit(id,direction,power,Controller.PROFILES[profile]):return false
        quiet_ticks=0
        return true
    var m=entry_model()
    var intended:Array=Common.state(m)
    var expected:Dictionary=points(pose,0.)
    if not physics.setup_model(m,profile,8,1):
        message="Box2D недоступен или вход не принят"
        return false
    var actual:Array=physics.world.state()
    velocity_error=0.
    for i in actual.size():
        for j in range(3,6):velocity_error=maxf(velocity_error,absf(float(actual[i][j])-float(intended[i][j])))
    var entry:Dictionary=physics.pose()
    var received:Dictionary=points(entry,0.)
    entry_error=0.
    for key in expected:entry_error=maxf(entry_error,Vector2(expected[key]).distance_to(received[key]))
    if entry_error>.02 or velocity_error>.02:
        message="Несовместимая входная поза: "+str(entry_error)
        physics.world=null
        return false
    if not physics.hit(id,direction,power,Controller.PROFILES[profile]):
        message="Импульс отклонён"
        return false
    origin=travel
    floor_y=m.floor_y
    phase=PHYSICS
    quiet_ticks=0
    return_requested=true
    message=""
    # Cancel rather than replay an interrupted attack marker after a fall.
    player.action=""
    player.age=0
    player.duration=0
    player.offsets.clear()
    player.slopes.clear()
    player.released.clear()
    player.landing.clear()
    player.recoil=0.
    player.recoil_velocity=0.
    player.events.clear()
    return true

func request_return()->void:
    return_requested=true

func bottom(p:Dictionary)->float:
    rig.evaluate(p)
    var low:float=-INF
    for segment in physics.model.bodies:
        var id:String=segment.id
        var ang:float=physics.model.rotation_for(id,p,rig.rotations)
        for sample in segment.samples:
            low=maxf(low,(rig.point(id)+Vector2(sample[0]).rotated(ang)).y+float(sample[1]))
    return low

func start_recovery()->void:
    recovery_from=pose.duplicate(true)
    recovery_to=player.final_pose.duplicate(true)
    # Keep the physical root's current world X; do not return to the launch location.
    recovery_travel=travel+float(pose.root[0])-float(recovery_to.root[0])
    recovery_from.root[0]=travel+float(pose.root[0])-recovery_travel
    recovery_age=0
    phase=RECOVERY

func step(cmd:Dictionary)->bool:
    previous=pose.duplicate(true)
    previous_travel=travel
    if phase==ASTRA:
        player.step(cmd)
        pose=player.final_pose.duplicate(true)
        travel=player.gait.travel+offset
    elif phase==PHYSICS:
        if not physics.step() or not physics.step():return false
        var p:Dictionary=physics.pose()
        travel=origin+float(p.root[0])
        p.root[0]=0.
        pose=p
        # Prepare a stopped target invisibly. No pending actions/hit markers.
        if not player.stopped or player.settle<1.:player.step({"speed":0.})
        player.events.clear()
        var v:Dictionary=Common.validate(physics.model)
        if v.speed<3. and v.near_floor>=2:quiet_ticks+=1
        else:quiet_ticks=0
        if return_requested and quiet_ticks>=12 and player.stopped and player.settle>=1.:
            start_recovery()
    else:
        recovery_age+=1
        var u:float=smoothstep(0.,1.,float(recovery_age)/RECOVERY_TICKS)
        var p:Dictionary=recovery_from.duplicate(true)
        for key in recovery_to.angles:
            var a:float=float(recovery_from.angles.get(key,recovery_to.angles[key]))
            var b:float=float(recovery_to.angles[key])
            if key in ["pelvis_turn","shoulder_turn"]:p.angles[key]=lerpf(a,b,u)
            else:p.angles[key]=a+wrapf(b-a,-180.,180.)*u
        for side in Leg.SIDES:
            Leg.put(p,side,lerpf(Leg.bend(recovery_from,side),Leg.bend(recovery_to,side),u),lerpf(Leg.ankle(recovery_from,side),Leg.ankle(recovery_to,side),u))
        for i in 2:p.root[i]=lerpf(float(recovery_from.root[i]),float(recovery_to.root[i]),u)
        # Prevent the interpolated body from cutting through the floor. Blend
        # endpoint proxy clearances so the final authored pose is not shifted.
        var ceiling:float=lerpf(maxf(floor_y,bottom(recovery_from)),maxf(floor_y,bottom(recovery_to)),u)
        p.root[1]-=maxf(0.,bottom(p)-ceiling)
        pose=p
        travel=recovery_travel
        if recovery_age>=RECOVERY_TICKS:
            pose=player.final_pose.duplicate(true)
            offset=travel-player.gait.travel
            phase=ASTRA
            return_requested=false
    rig.evaluate(pose)
    return true

func snapshot()->Dictionary:
    return {"player":player.save(),"phase":phase,"pose":pose.duplicate(true),"previous":previous.duplicate(true),"travel":travel,"previous_travel":previous_travel,"offset":offset,"origin":origin,"recovery_age":recovery_age,"recovery_from":recovery_from.duplicate(true),"recovery_to":recovery_to.duplicate(true),"recovery_travel":recovery_travel,"quiet_ticks":quiet_ticks,"return_requested":return_requested,"floor_y":floor_y,"physics":physics.snapshot() if physics.world!=null else {}}

func restore(s:Dictionary)->bool:
    # Local trusted same-generation restore; a new physical episode creates a new world.
    if not s.physics.is_empty() and not physics.restore(s.physics):return false
    if s.physics.is_empty() and physics.world!=null:return false
    player.restore(s.player)
    phase=s.phase
    pose=s.pose.duplicate(true)
    previous=s.previous.duplicate(true)
    travel=s.travel
    previous_travel=s.previous_travel
    offset=s.offset
    origin=s.origin
    recovery_age=s.recovery_age
    recovery_from=s.recovery_from.duplicate(true)
    recovery_to=s.recovery_to.duplicate(true)
    recovery_travel=s.recovery_travel
    quiet_ticks=s.quiet_ticks
    return_requested=s.return_requested
    floor_y=s.floor_y
    rig.evaluate(pose)
    return true
