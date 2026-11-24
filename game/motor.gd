extends RefCounted
## Fixed-step root movement and planted-foot state. All positions are world pixels.
const STANCE=preload("res://game/guard_pose.gd")
const FLOOR=430.0
const DT=1.0/120.0
const WALK=135.0
const RUN=215.0
const GRAVITY=1000.0
const JUMP=395.0
const ACCEL=1150.0
const BRAKE=1500.0
const STEP_TIME=.16
var pos:Vector2
var velocity:=Vector2.ZERO
var facing:int=1
var grounded:bool=true
var feet:Array[Vector2]=[]
var swing:int=-1
var next_foot:int=0
var swing_from:=Vector2.ZERO
var swing_to:=Vector2.ZERO
var swing_t:float=0
var swing_duration:float=STEP_TIME
var swing_height:float=10
var run_mix:float=0
var takeoff_feet:Array[Vector2]=[]
var takeoff_gait:float=0
var takeoff_run:float=0
var jump_latch:bool=false
var land:float=0
var airborne_time:float=0
var steps:int=0
var time:float=0
var gait:float=0
var guard_phase:float=0
var sprint:bool=false
func _init(x:float,side:int)->void:
    pos=Vector2(x,FLOOR)
    facing=side
    _plant()
func _plant()->void:
    feet.assign([Vector2(pos.x+STANCE.HALF_WIDTH*facing,FLOOR),Vector2(pos.x-STANCE.HALF_WIDTH*facing,FLOOR)])
    swing=-1
    swing_t=0
func _begin_step(index:int,axis:float)->void:
    swing=index
    swing_from=feet[index]
    # Freeze the step duration at lift-off; changing Shift mid-step cannot snap a foot.
    var moving:bool=absf(axis)>.01
    var fast:bool=moving and sprint and axis*facing>0
    swing_duration=.13 if fast else (.18 if moving else .15)
    swing_height=23.0 if fast else (10.0 if moving else 6.0)
    var ahead:float=signf(axis)*(17.0+absf(axis)*swing_duration)
    if not moving:ahead=(STANCE.HALF_WIDTH if index==0 else -STANCE.HALF_WIDTH)*facing
    swing_to=Vector2(clampf(pos.x+ahead,32,928),FLOOR)
    swing_t=0
    next_foot=1-index
func tick(input:Dictionary,opponent_x:float)->void:
    time+=DT
    var axis:float=clampf(float(input.get("move",0)),-1,1)
    sprint=bool(input.get("run",false))
    var jump:bool=bool(input.get("jump",false))
    if input.get("kick_support",false):
        # Start only from settled footing. Freeze the root and both motor anchors;
        # the visible lead ankle is driven by the attack pose, not gait.
        velocity.x=0
        jump_latch=jump
        guard_phase=fposmod(guard_phase+DT,STANCE.DURATION)
        gait=move_toward(gait,0,DT*8)
        run_mix=move_toward(run_mix,0,DT*6)
        land=move_toward(land,0,DT*6)
        return
    if grounded and not input.get("lock_facing",false) and absf(opponent_x-pos.x)>5:facing=1 if opponent_x>pos.x else -1
    # Backpedal in guard rather than playing a forward sprint backwards.
    var backward:bool=axis*facing<0
    var target:float=axis*(96.0 if backward else (RUN if sprint else WALK))
    velocity.x=move_toward(velocity.x,target,DT*(550.0 if input.get("hurt",false) else (BRAKE if absf(axis)<.01 else ACCEL)))
    if grounded and jump and not jump_latch:
        takeoff_feet.clear()
        for foot in feet:takeoff_feet.append(Vector2((foot.x-pos.x)*facing,foot.y-pos.y-2))
        takeoff_gait=gait
        takeoff_run=run_mix
        velocity.y=-JUMP
        grounded=false
        airborne_time=0
        swing=-1
    jump_latch=jump
    if not grounded:velocity.y+=GRAVITY*DT
    pos+=velocity*DT
    pos.x=clampf(pos.x,48,912)
    if pos.x<=48 or pos.x>=912:velocity.x=0
    if not grounded and pos.y>=FLOOR:
        pos.y=FLOOR
        velocity.y=0
        grounded=true
        land=1
        _plant()
    land=move_toward(land,0,DT*6)
    if not grounded:
        airborne_time+=DT
        return
    gait=move_toward(gait,clampf(absf(velocity.x)/WALK,0,1),DT*8)
    run_mix=move_toward(run_mix,clampf((velocity.x*facing-WALK)/(RUN-WALK),0,1),DT*6)
    # Continue phase only as a breathing/weight cycle; never move planted feet.
    guard_phase=fposmod(guard_phase+DT,STANCE.DURATION)
    if swing>=0:
        swing_t=minf(swing_duration,swing_t+DT)
        var u:float=swing_t/swing_duration
        var eased:float=u*u*(3-2*u)
        feet[swing]=swing_from.lerp(swing_to,eased)
        # Early knee lift, late reach and settling, based on the running/walking silhouettes.
        feet[swing].y-=pow(sin(u*PI),1.25)*swing_height
        if u>=1:
            feet[swing]=swing_to
            swing=-1
            steps+=1
    if swing<0:
        if input.get("settle_kick",false):return
        if absf(velocity.x)>10:
            var trailing:int=0 if (feet[0].x-feet[1].x)*velocity.x<=0 else 1
            if (pos.x-feet[trailing].x)*signf(velocity.x)>8 or absf(feet[0].x-feet[1].x)<12:_begin_step(trailing,velocity.x)
        else:
            # Return to a stable stance one foot at a time, never teleport feet.
            var desired:float=pos.x+STANCE.HALF_WIDTH*facing
            if absf(feet[0].x-desired)>4:_begin_step(0,0)
            elif absf(feet[1].x-(pos.x-STANCE.HALF_WIDTH*facing))>4:_begin_step(1,0)
func separate(dx:float)->void:
    pos.x+=dx
    # Push-box displacement moves the whole support frame, not only the pelvis.
    for i in range(feet.size()):feet[i].x+=dx
    swing_from.x+=dx
    swing_to.x+=dx
