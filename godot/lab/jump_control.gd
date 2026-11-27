extends RefCounted
## One directional jump. World flight is independent of the local FK/IK pose.
const Motion=preload("res://lab/walk_motion.gd")
const Walk=preload("res://lab/walk_control.gd")
const Clips=preload("res://addons/creature/clips.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const Entry=preload("res://lab/motion_entry.gd")
var moving_entry
var push_leg:int
var plant_tick:int
var plant_x:float
const PREP_TICKS:int=6
const FLIGHT_TICKS:int=48
const HEIGHT_SCALE:float=1.35
const DEFAULTS={"height_scale":1.35,"flight_seconds":.8,"power_scale":1.35,"tuck_scale":1.25,"second_height_scale":.55,"second_speed_scale":1.25,"second_power_scale":1.15}
const MAX_SPEED:float=64. # rig units / second
const AIR_ACCEL:float=110.
const CROWN:float=4.7 # accepted 069 head mesh extent
# Per-jump tuning; first-jump defaults are the accepted v12 candidate. Settings are locked
# while a jump is active so the trajectory cannot change discontinuously.
var height_scale:float=HEIGHT_SCALE
var flight_ticks:int=FLIGHT_TICKS
var power_scale:float=1.35
var tuck_scale:float=1.25
var second_height_scale:float=.55
var second_speed_scale:float=1.25
var second_power_scale:float=1.15
var second_used:bool=false
var second_ticks:int=0
var second_time:float=0.
var second_origin:float=0.
var second_peak:float=0.
var second_vy:float=0.
var gravity:float=0.
var second_direction:int=0
var second_entry:Dictionary={}
var second_toes:Array=[]
var air_speed_limit:float=MAX_SPEED
var state:int=0 # 0 ground, 1 preparation, 2 flight
var age:int=0
var altitude:float=0.
var body_height:float=52.7
var height:float=52.7*HEIGHT_SCALE
var vx:float=0.
var launch_direction:int=0
var inherited_speed:float=0.
var launch_vx:float=0.
var prep_origin:float=0.
var entry:Dictionary={}
var entry_toes:Array=[]
var guard:Dictionary={}
var launch_pose:Dictionary={}
var launch_toes:Array=[]

func configure(settings:Dictionary)->bool:
    if state!=0:return false
    height_scale=clampf(float(settings.get("height_scale",HEIGHT_SCALE)),.5,1.7)
    flight_ticks=clampi(roundi(float(settings.get("flight_seconds",.8))*60.),24,84)
    power_scale=clampf(float(settings.get("power_scale",DEFAULTS.power_scale)),.5,1.5)
    tuck_scale=clampf(float(settings.get("tuck_scale",DEFAULTS.tuck_scale)),0.,1.5)
    second_height_scale=clampf(float(settings.get("second_height_scale",DEFAULTS.second_height_scale)),.25,.8)
    second_speed_scale=clampf(float(settings.get("second_speed_scale",DEFAULTS.second_speed_scale)),1.,1.5)
    second_power_scale=clampf(float(settings.get("second_power_scale",DEFAULTS.second_power_scale)),.5,1.5)
    return true

func _phase(a:float,b:float,u:float)->float:
    return smoothstep(a,b,clampf(u,0.,1.))

func start(w,command:int)->bool:
    if state!=0:return false
    entry=w.pose.duplicate(true)
    entry_toes=Motion.toes(w.rig,entry)
    w.guard_lead=Walk.lead_of(entry_toes,w.guard_lead)
    guard=w.guard_intent(w.programs.walk_idle,0.)
    var _standing:Dictionary=Motion.resolve(w.rig,w.support,guard)
    body_height=clampf(-Vector2(w.rig.point("head")).y+CROWN,35.,70.)
    height=body_height*height_scale
    var flight_seconds:float=float(flight_ticks)/60.
    gravity=8.*height/(flight_seconds*flight_seconds)
    second_used=false
    second_ticks=0
    second_time=0.
    second_origin=0.
    second_peak=0.
    second_vy=0.
    # Capture the actual signed ground velocity before the ground motor
    # is suspended. Opposite input steers in flight; it cannot flip momentum
    # at the first takeoff. The second impulse still may redirect sharply.
    inherited_speed=float(w.ground_speed)
    prep_origin=float(w.x)
    var requested:int=clampi(command,-1,1)
    launch_direction=(1 if inherited_speed>0. else -1) if absf(inherited_speed)>.01 else requested
    launch_vx=MAX_SPEED*launch_direction
    if absf(inherited_speed)>.01:
        if requested==0 or requested!=launch_direction:launch_vx=inherited_speed
        else:launch_vx=launch_direction*maxf(MAX_SPEED,absf(inherited_speed))
    air_speed_limit=maxf(MAX_SPEED,absf(launch_vx))
    w.rig.evaluate(entry)
    moving_entry=null
    if w.sprint_active and absf(inherited_speed)>.01:
        moving_entry=Entry.new(w)
        launch_vx=inherited_speed
        # During flight the distance calendar identifies the next receiving foot.
        push_leg=w.run_gait.side
        if not moving_entry.contacts[push_leg]:
            push_leg=1-push_leg
        plant_tick=0 if moving_entry.contacts[push_leg] else 3
        plant_x=moving_entry.anchors[push_leg].x
        if plant_tick>0:
            plant_x=w.x+inherited_speed*plant_tick/60.+moving_entry.toe_at(push_leg,plant_tick,PREP_TICKS).x
    w.suspend_motion()
    w.direction=0
    w.idle_active=false
    w.idle_ticks=0
    state=1
    age=0
    altitude=0.
    vx=0.
    return true

func step(w,command:int)->void:
    age+=1
    if state==1:
        if moving_entry!=null:
            running_push(w)
            if age==PREP_TICKS:
                launch_pose=w.pose.duplicate(true)
                launch_toes=Motion.toes(w.rig,w.pose)
                state=2
                age=0
                vx=launch_vx
            return
        # Dynamic prep: brief sink, then explosive extension into takeoff.
        var u:float=float(age)/PREP_TICKS
        var settle:float=_phase(0.,0.35,u)
        var crouch:float=_phase(0.02,0.34,u)*(1.-_phase(0.42,0.72,u))*power_scale
        var drive:float=_phase(0.46,1.,u)*power_scale
        # A running takeoff carries the root forward through a short planted
        # push instead of visually freezing for all six preparation ticks.
        if absf(inherited_speed)>MAX_SPEED:
            var carry:float=inherited_speed*.35*(1.-.5*u)/60.
            w.x=clampf(w.x+carry,-w.travel_limit,w.travel_limit)
        var twist:float=launch_direction*(0.55*crouch+0.9*drive)
        var p:Dictionary=Clips.blend_pose(entry,guard.pose,settle)
        p.root[1]+=4.2*crouch-1.1*drive
        p.root[0]+=0.9*launch_direction*drive
        p.angles.hips+=11.*twist-6.5*crouch
        p.angles.chest+=8.*twist-4.0*crouch
        p.angles.head+=2.2*crouch-8.0*drive
        p.angles.shoulder_turn+=5.*launch_direction*crouch+9.*launch_direction*drive
        p.angles.shoulder_near+=18.*crouch+4.*drive
        p.angles.elbow_near+=16.*crouch+14.*drive
        p.angles.shoulder_far+=13.*crouch-12.*drive
        p.angles.elbow_far+=8.*crouch+10.*drive
        p.angles.thigh_near+=7.5*crouch-9.5*drive
        p.angles.knee_near+=17.0*crouch-14.0*drive
        p.angles.thigh_far+=9.5*crouch-12.0*drive
        p.angles.knee_far+=19.0*crouch-16.0*drive
        var paths:Array=[]
        for i in 2:
            var toe:Vector2=entry_toes[i]
            toe.y=lerpf(toe.y,0.,settle)
            if absf(inherited_speed)>MAX_SPEED:
                toe.x-=w.x-prep_origin # keep planted targets in world space
            else:
                toe.x+=launch_direction*(0.45 if i==w.guard_lead else -0.25)*crouch
            paths.append({"toe":toe,"pitch":lerpf(float(entry.angles["foot_pitch_"+Motion.SIDES[i]]),-2.5*drive,settle),"stance":absf(toe.y)<.02})
        w.set_intent({"pose":p,"paths":paths})
        if age>=PREP_TICKS:
            launch_pose=w.pose.duplicate(true)
            launch_toes=Motion.toes(w.rig,w.pose)
            state=2
            age=0
            vx=launch_vx
        return
    if state!=2:return
    if second_used:
        step_second(w,command)
        return
    var u:float=clampf(float(age)/flight_ticks,0.,1.)
    altitude=height*4.*u*(1.-u)
    # No-input retains inertia; a held direction changes speed gradually.
    if command!=0:vx=move_toward(vx,air_speed_limit*clampi(command,-1,1),AIR_ACCEL/60.)
    var next:float=clampf(w.x+vx/60.,-w.travel_limit,w.travel_limit)
    if absf(next-w.x-vx/60.)>.0001:vx=0.
    w.x=next
    var lean:float=clampf(vx/MAX_SPEED,-1.4,1.4)
    var movement_lead:int=w.guard_lead if launch_direction>=0 else (1-w.guard_lead if launch_direction<0 else w.guard_lead)
    var stretch:float=_phase(0.0,0.16,u)*(1.-_phase(0.18,0.38,u))*power_scale
    var apex_tuck:float=_phase(0.16,0.42,u)*(1.-_phase(0.56,0.82,u))*tuck_scale
    var descent:float=_phase(0.62,1.0,u)
    var airborne:float=maxf(maxf(stretch,apex_tuck),descent)
    var launch_mix:float=_phase(0.0,0.22,u)
    var p:Dictionary=Clips.blend_pose(launch_pose,guard.pose,launch_mix)
    # Introduce flight accents from zero at lift-off, including foot pitch.
    var onset:float=_phase(0.,.14,u) if moving_entry!=null else 1.
    p.root[0]+=onset*2.2*lean*(0.25+0.75*airborne)
    p.root[1]-=.8*stretch
    p.angles.hips+=15.*lean*(0.5*stretch+.55*apex_tuck)-10.0*lean*descent
    p.angles.chest+=11.*lean*(0.45*stretch+.35*apex_tuck)-8.0*lean*descent
    p.angles.head+=3.0*apex_tuck-7.5*stretch+5.5*descent
    p.angles.shoulder_turn+=onset*11.*lean*(0.35+0.65*airborne)
    p.angles.shoulder_near+=12.*stretch+19.*apex_tuck-9.*descent+onset*6.*lean
    p.angles.elbow_near+=8.*stretch+24.*apex_tuck+10.*descent
    p.angles.shoulder_far+=19.*stretch+11.*apex_tuck-6.*descent+onset*4.*lean
    p.angles.elbow_far+=10.*stretch+18.*apex_tuck+8.*descent
    var paths:Array=[]
    for i in 2:
        var goal:Vector2=guard.paths[i].toe
        var toe:Vector2=Vector2(launch_toes[i]).lerp(goal,launch_mix)
        var front:bool=i==movement_lead
        toe.x+=2.8*lean*stretch+2.2*lean*apex_tuck+1.5*lean*descent
        toe.x+=(2.8 if front else -2.4)*stretch
        toe.x+=(3.9 if front else -1.6)*apex_tuck
        toe.x+=(5.2 if front else -2.1)*descent
        toe.y-=(5.2 if front else 3.6)*stretch
        toe.y-=(11.5 if front else 8.3)*apex_tuck
        toe.y-=(3.2 if front else 2.4)*descent
        var pitch:float=10.*stretch+7.*apex_tuck-4.5*descent
        if moving_entry!=null:
            pitch=lerpf(launch_pose.angles["foot_pitch_"+Motion.SIDES[i]],pitch,onset)
        paths.append({"toe":toe,"pitch":pitch,"stance":false})
    if age>=flight_ticks:
        land(w)
        return
    w.set_intent({"pose":p,"paths":paths,"support_load":[0.,0.]})

# The receiver owns load/extension timing. Source tangents supply the
# initial directions, and a single arena-space point supports the push.
func running_push(w)->void:
    var e=moving_entry
    var u:=float(age)/PREP_TICKS
    var load:=sin(PI*u)*power_scale
    var drive:=smoothstep(.35,1.,u)*power_scale
    w.x=clampf(w.x+e.velocity/60.,-w.travel_limit,w.travel_limit)
    var p:Dictionary=e.continued(age,PREP_TICKS)
    p.root[1]+=2.8*load-.5*drive
    p.angles.chest-=3.*drive
    var paths:Array=[]
    for i in 2:
        var side:String=Motion.SIDES[i]
        var toe:Vector2=e.toe_at(i,age,PREP_TICKS)
        var planted:bool=i==push_leg and age>=plant_tick
        if i==push_leg:
            var approach:=1. if plant_tick==0 else smoothstep(0.,float(plant_tick),float(age))
            toe=toe.lerp(Vector2(plant_x-w.x,0.),approach)
        else:
            toe.x+=launch_direction*2.*drive
            toe.y-=2.8*drive
        toe.y=minf(0.,toe.y)
        var pitch:float=p.angles["foot_pitch_"+side]
        paths.append({"toe":toe,"pitch":pitch,"stance":planted})
    var loads:=[0.,0.]
    if paths[push_leg].stance:loads[push_leg]=1.
    w.set_intent({"pose":p,"paths":paths,"support_load":loads})
    if paths[push_leg].stance:
        # IK may saturate its reach or ankle limit. Transfer the remaining
        # displacement to the pelvis around the supporting toe.
        var actual:=Motion.toe(w.rig,w.pose,Motion.SIDES[push_leg])
        var correction:Vector2=paths[push_leg].toe-actual
        w.pose.root[0]=Grid.scalar(w.pose.root[0]+correction.x)
        w.pose.root[1]=Grid.scalar(w.pose.root[1]+correction.y)
        w.rig.evaluate(w.pose)
        # A low free foot may cross the floor after the pelvis correction.
        var free_side:String=Motion.SIDES[1-push_leg]
        var free_toe:=Motion.toe(w.rig,w.pose,free_side)
        if free_toe.y>.001:
            var ankle:Vector2=paths[1-push_leg].toe-IK.toe_vector(w.pose,free_side)
            IK.solve_leg(w.rig,w.pose,free_side,ankle,1.)
            Leg.put(w.pose,free_side,Leg.bend(w.pose,free_side),Leg.ankle(w.pose,free_side))
            Grid.pose(w.pose)
            w.rig.evaluate(w.pose)

# A fresh press only, after leaving the ground; no third impulse.
func can_second()->bool:
    return state==2 and not second_used and altitude>0.

func try_second(w,command:int)->bool:
    if not can_second():return false
    second_used=true
    second_origin=altitude
    second_entry=w.pose.duplicate(true)
    second_toes=Motion.toes(w.rig,w.pose)
    second_direction=clampi(command,-1,1)
    # Same gravity as the first arc. Set upward velocity, not position.
    # A positive root of y(t)=0 gives the remaining flight time.
    var extra:float=body_height*second_height_scale
    second_vy=sqrt(2.*gravity*extra)
    second_peak=second_origin+extra
    second_time=(second_vy+sqrt(second_vy*second_vy+2.*gravity*second_origin))/gravity
    second_ticks=maxi(1,ceili(second_time*60.))
    age=0
    air_speed_limit=maxf(MAX_SPEED,air_speed_limit)*second_speed_scale
    if second_direction!=0:vx=air_speed_limit*second_direction
    # No command: preserve horizontal momentum, add only vertical impulse.
    return true

func step_second(w,command:int)->void:
    var elapsed:float=minf(float(age)/60.,second_time)
    altitude=maxf(0.,second_origin+second_vy*elapsed-.5*gravity*elapsed*elapsed)
    if command!=0:vx=move_toward(vx,air_speed_limit*clampi(command,-1,1),AIR_ACCEL/60.)
    var target:float=clampf(w.x+vx/60.,-w.travel_limit,w.travel_limit)
    if absf(target-w.x-vx/60.)>.0001:vx=0.
    w.x=target
    if age>=second_ticks:
        land(w)
        return
    # Pose begins at the actual in-air pose, not a fixed ground pose.
    # Short chamber -> sharp asymmetric air step -> compact ascent -> guard.
    var u:float=elapsed/second_time
    var chamber:float=_phase(0.,.06,u)*(1.-_phase(.07,.18,u))*second_power_scale
    var push:float=_phase(.04,.15,u)*(1.-_phase(.20,.39,u))*second_power_scale
    var tuck:float=_phase(.18,.38,u)*(1.-_phase(.52,.85,u))*tuck_scale
    var blend:float=_phase(0.,.28,u)
    var settle:float=_phase(.78,1.,u)
    var aim:float=clampf(vx/air_speed_limit,-1.,1.)
    var directed:float=float(second_direction)
    var lead:int=w.guard_lead if second_direction>=0 else 1-w.guard_lead
    var p:Dictionary=Clips.blend_pose(second_entry,guard.pose,blend)
    p.root[0]+=aim*(1.8*push+.8*tuck)
    p.root[1]+=1.4*chamber-.9*push
    p.angles.hips+=directed*(8.*chamber+16.*push+5.*tuck)-4.*chamber
    p.angles.chest+=directed*(10.*push+5.*tuck)-7.*chamber
    p.angles.head+=6.*chamber-9.*push+3.*tuck
    p.angles.shoulder_turn+=directed*(12.*push+6.*tuck)
    for i in 2:
        var side:String=Motion.SIDES[i]
        var front:bool=i==lead
        p.angles["shoulder_"+side]+=(12. if front else -18.)*push+14.*chamber+10.*tuck
        p.angles["elbow_"+side]+=(18. if front else 7.)*push+20.*chamber+12.*tuck
    var paths:Array=[]
    for i in 2:
        var front:bool=i==lead
        var toe:Vector2=Vector2(second_toes[i]).lerp(Vector2(guard.paths[i].toe),blend)
        toe.x+=directed*(2.2*push+1.2*tuck)+(2.6 if front else -2.6)*push
        toe.y-=(5. if front else 6.5)*chamber
        toe.y-=(8. if front else 1.5)*push
        toe.y-=(8. if front else 10.)*tuck
        var initial_pitch:float=float(second_entry.angles["foot_pitch_"+Motion.SIDES[i]])
        var pitch:float=lerpf(initial_pitch,float(guard.paths[i].pitch),blend)+7.*chamber+(8. if front else 16.)*push
        # Explicit convergence to grounded contact; no last-frame toe reset.
        toe=toe.lerp(Vector2(guard.paths[i].toe),settle)
        pitch=lerpf(pitch,float(guard.paths[i].pitch),settle)
        paths.append({"toe":toe,"pitch":pitch,"stance":false})
    w.set_intent({"pose":p,"paths":paths,"support_load":[0.,0.]})

func land(w)->void:
    altitude=0.
    state=0
    vx=0.
    var landed:Dictionary=guard.duplicate(true)
    landed.pose.root[1]+=1.35
    landed.pose.angles.head+=4.0
    landed.pose.angles.chest-=3.0
    w.set_intent(landed)
    w.capture_transition()
    w.direction=0
