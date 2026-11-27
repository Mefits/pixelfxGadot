extends RefCounted
const Punch=preload("res://lab/training_punch.gd")
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
    if d.get("training_attack",false):
        var stance:Dictionary=Motion.document("walk_idle")
        program={"doc":d,"fixed":Motion.toes(rig,Motion.sample(stance,0.))}
    else:program=Motion.prepare(d)
    action=d.id
    stopped=d.get("walk_role","")=="walk_idle"
    update(0.)
func step(_cmd:Dictionary)->void:
    frame+=1
    var t:float=clampf(float(frame-30)/60.,0.,float(program.doc.duration))
    update(t/float(program.doc.duration))
func update(phase:float)->void:
    var intent:Dictionary=Punch.intent(program.doc,phase*float(program.doc.duration),rig,program.fixed) if program.doc.get("training_attack",false) else Motion.intent(program,phase,rig)
    paths=intent.paths
    if program.doc.get("training_attack",false):
        final_pose=intent.pose
        rig.evaluate(final_pose)
    else:final_pose=Motion.resolve(rig,support,intent)
    for i in 2:
        anchors["foot_"+Motion.SIDES[i]]=Motion.toe(rig,final_pose,Motion.SIDES[i])
