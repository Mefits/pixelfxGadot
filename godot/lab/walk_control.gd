extends RefCounted
## Independent input/locomotion experiment. No changes to the accepted Astra kernel.
## A signed distance samples the accepted walk calendar in either direction.
## Facing is constant. Backward walk is a provisional reversed cycle, not a new authored clip.
const Asset=preload("res://lab/authoring/asset.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Gait=preload("res://lab/hybrid091/gait.gd")
const Support=preload("res://lab/hybrid091/support.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const SPEED:float=.5
const LIMIT:float=48.
const FACING:int=1
var rig=Body.make_rig()
var gait
var support
var x:float=0.
var phase_distance:float=1.
var activity:float=0.
var direction:int=0
var pose:Dictionary={}
var paths:Array=[]
var ticks:int=0

func _init():
    var clip:Dictionary=Asset.read(Asset.FIX+"run053a_C.json").payload.clip
    gait=Gait.new(rig,clip)
    support=Support.new(rig)
    sample()

func step(command:int)->void:
    var next:float=clampf(x+clampi(command,-1,1)*SPEED,-LIMIT,LIMIT)
    var dx:float=next-x
    direction=0 if is_zero_approx(dx) else (1 if dx>0. else -1)
    x=next
    phase_distance+=dx
    activity=move_toward(activity,1. if direction!=0 else 0.,.125)
    ticks+=1
    sample()

func sample()->void:
    var stride:float=Gait.WALK_STEP
    var local:float=fposmod(phase_distance,2.*stride)
    var q:float=floorf(local/stride)*stride
    var side:int=int(q/stride)
    gait.travel=local
    gait.velocity=1.
    gait.side=side
    gait.queue=[q,q+stride,q+2.*stride]
    gait.legs[side]={"start":q,"end":q+2.*stride}
    gait.legs[1-side]={"start":q-stride,"end":q+stride}
    var intent:Dictionary=gait.intent()
    pose=intent.pose
    paths=intent.paths
    # Stop translation immediately. Lower the free toe in place and relax
    # the torso; no negative speed is passed into the original kernel.
    pose.angles.hips=lerpf(2.,float(pose.angles.hips),activity)
    pose.angles.chest=lerpf(0.,float(pose.angles.chest),activity)
    pose.angles.head=lerpf(-2.,float(pose.angles.head),activity)
    pose.root[1]=lerpf(2.5,float(pose.root[1]),activity)
    for side_name in ["near","far"]:
        pose.angles["shoulder_"+side_name]=lerpf(-15.,float(pose.angles["shoulder_"+side_name]),activity)
        pose.angles["elbow_"+side_name]=lerpf(-85.,float(pose.angles["elbow_"+side_name]),activity)
    for path in paths:
        path.toe.y*=activity
        path.pitch*=activity
        path.toe=Grid.point(path.toe)
        path.pitch=Grid.scalar(path.pitch)
        if activity==0.:path.stance=true
    Grid.pose(pose)
    support.resolve(pose,paths)

func action_name()->String:
    return "walk_forward" if direction>0 else ("walk_backward" if direction<0 else "idle")
