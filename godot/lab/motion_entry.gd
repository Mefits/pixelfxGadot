extends RefCounted
## Boundary sample of two consecutive solved poses at 60 Hz. Endpoints
## are local to the moving motor; anchors are expressed in arena space.
const Motion=preload("res://lab/walk_motion.gd")
var pose:Dictionary
var angles:Dictionary={}
var root_step:Vector2
var toes:Array
var toe_steps:Array=[]
var contacts:Array=[]
var anchors:Array=[]
var velocity:float

func _init(w):
    pose=w.pose.duplicate(true)
    velocity=w.ground_speed
    var prior:Dictionary=w.previous_pose if not w.previous_pose.is_empty() else pose
    for id in pose.angles:
        angles[id]=wrapf(pose.angles[id]-prior.angles.get(id,pose.angles[id]),-180.,180.)
    root_step=Vector2(pose.root[0]-prior.root[0],pose.root[1]-prior.root[1])
    var earlier:=Motion.toes(w.rig,prior)
    toes=Motion.toes(w.rig,pose)
    for i in toes.size():
        toe_steps.append(toes[i]-earlier[i])
        contacts.append(bool(w.paths[i].stance))
        anchors.append(toes[i]+Vector2.RIGHT*w.x)

# Integrated linearly decaying velocity. Unit slope at entry, zero at
# the horizon. Incoming actions can add their own displacement at any tick.
static func advance_ticks(age:int,horizon:int)->float:
    var t:=minf(age,horizon)
    return t*(1.-t/(2.*horizon))

func continued(age:int,horizon:int)->Dictionary:
    var t:=advance_ticks(age,horizon)
    var p:=pose.duplicate(true)
    for id in angles:p.angles[id]+=angles[id]*t
    p.root[0]+=root_step.x*t
    p.root[1]+=root_step.y*t
    return p

func toe_at(index:int,age:int,horizon:int)->Vector2:
    return toes[index]+toe_steps[index]*advance_ticks(age,horizon)
