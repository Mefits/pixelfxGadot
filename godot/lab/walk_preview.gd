extends RefCounted
const Motion=preload("res://lab/walk_motion.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Support=preload("res://lab/hybrid091/support.gd")
var rig=Body.make_rig()
var support=Support.new(rig)
var program:Dictionary
var final_pose:Dictionary
var paths:Array
var stopped:bool=false
var action:String
var style:float=0.
var goal_report:Dictionary={}
var gait:Dictionary={"travel":0.}
var anchors:Dictionary={}
var frame:int=-1
func _init(d:Dictionary):
    program=Motion.prepare(d)
    action=d.id
    stopped=d.walk_role=="walk_idle"
    update(0.)
func step(_cmd:Dictionary)->void:
    frame+=1
    var t:float=clampf(float(frame-30)/60.,0.,float(program.doc.duration))
    update(t/float(program.doc.duration))
func update(phase:float)->void:
    var intent:Dictionary=Motion.intent(program,phase,rig)
    paths=intent.paths
    final_pose=Motion.resolve(rig,support,intent)
    for i in 2:
        anchors["foot_"+Motion.SIDES[i]]=Motion.toe(rig,final_pose,Motion.SIDES[i])
