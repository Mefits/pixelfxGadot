extends RefCounted
## Lab-only horizontal world motor. Controller pose coordinates are in a
## moving reference frame; render and marker positions are in world space.
## No physics body, wall collision, true sole contact or network code.
const Planner=preload("res://lab/sparse_transition_081.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Recovery=preload("res://lab/stance_recovery_078.gd")
const SPEED:float=2.15 # rig units/tick
const ACCEL:float=.22
const BRAKE:float=.40
var rig
var player
var mode:int
var travel:float=0.
var velocity:float=0.
var anchor_side:=" "
var anchor:=Vector2.ZERO
var prior_source:Dictionary={}
var lock_age:int=0
var lock_release:int=0
var previous_world:Dictionary={}

func _init(r,v:int):
    rig=r
    mode=v
    player=Planner.new(r,1 if v==0 else 2)

func command(a:Dictionary)->void:
    player.command(a)
    anchor_side=""
    prior_source.clear()
    lock_age=0
    lock_release=0

func world_pose(local:Dictionary)->Dictionary:
    var p:Dictionary=local.duplicate(true)
    p.root[0]=float(p.root[0])+travel
    return p

func step()->Dictionary:
    var start:int=Time.get_ticks_usec()
    var running:bool=player.action.loop
    velocity=move_toward(velocity,SPEED if running else 0.,ACCEL if running else BRAKE)
    travel+=velocity
    var v:Dictionary=player.step()
    var p:Dictionary=world_pose(v.pose)
    var target:Dictionary=world_pose(v.target)
    var raw_toes:Dictionary=player.toes(v.target)
    var error:float=0.
    var correction:float=0.
    var applied:bool=false
    # Only acquire a stance contact on the incoming run once the pose
    # correction has converged. Use height and backward source velocity;
    # do not pin the foot as it sweeps forward or while airborne.
    if mode==2 and running and v.local>=v.duration and not prior_source.is_empty():
        var chosen:=""
        var best:float=INF
        for side in IK.SIDES:
            var toe:Vector2=raw_toes[side]
            var old:Vector2=prior_source[side]
            if absf(toe.y)<1.25 and toe.x-old.x<-.55:
                var score:float=absf(toe.y)+.1*absf(toe.x-old.x+velocity)
                if score<best:
                    chosen=side
                    best=score
        if anchor_side!="":
            var toe:Vector2=raw_toes[anchor_side]
            var old:Vector2=prior_source[anchor_side]
            if toe.y< -2.1 or toe.y>1.5 or toe.x-old.x>-.15:
                lock_release+=1
            else:lock_release=0
        if anchor_side=="" and chosen!="":
            anchor_side=chosen
            anchor=Vector2(raw_toes[chosen])+Vector2(travel,0.)
            lock_age=0
            lock_release=0
        if anchor_side!="":
            rig.evaluate(p)
            var side:String=anchor_side
            var ankle:Vector2=rig.point("foot_"+side)
            var current_toe:Vector2=ankle+IK.toe_vector(p,side)
            var fade:float=smoothstep(0.,3.,float(lock_age))
            if lock_release>0:fade*=1.-smoothstep(0.,3.,float(lock_release))
            var delta:Vector2=(anchor-current_toe).limit_length(3.5)*fade
            var goal:Vector2=ankle+delta
            var q:Dictionary=rig.points.duplicate(true)
            IK.solve_leg(rig,p,side,goal,Recovery.bend_sign(q,side))
            rig.evaluate(p)
            error=rig.point("foot_"+side).distance_to(goal)
            correction=delta.length()
            applied=true
            lock_age+=1
            if lock_release>=3:
                anchor_side=""
                lock_age=0
                lock_release=0
    prior_source=raw_toes
    # Feed the actual displayed, contact-corrected pose back to the player
    # in its own reference frame, so the next command starts from it.
    var local:Dictionary=p.duplicate(true)
    local.root[0]=float(local.root[0])-travel
    player.current=local
    var step_us:int=Time.get_ticks_usec()-start
    v["pose"]=p
    v["target"]=target
    v["travel"]=travel
    v["velocity"]=velocity
    v["run_lock"]=applied
    v["run_lock_error"]=error
    v["run_correction"]=correction
    v["step_us"]=step_us
    v["run_anchor_side"]=anchor_side
    return v
