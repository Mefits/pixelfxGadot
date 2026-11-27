extends RefCounted
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Clips=preload("res://addons/creature/clips.gd")
const IDS=["combo_original_1","combo_original_2","combo_original_3"]
const BOUNDARIES=[0,28,38,76]
const SOURCE=Asset.FIX+"combo052a2_B.json"

static func source()->Dictionary:
    return Asset.read(SOURCE).payload.clip

static func default_doc(id:String)->Dictionary:
    var index:int=IDS.find(id)
    var clip:Dictionary=source()
    var first:int=BOUNDARIES[index]
    var last:int=BOUNDARIES[index+1]
    var keys:Array=[]
    for tick in range(first,last+1):
        var k:Dictionary=clip.keys[tick]
        keys.append(Motion.key(float(tick-first)/60.,k.pose))
    var marker:Dictionary=clip.events[index].duplicate(true)
    marker.t=float(roundi(float(marker.t)*60.)-first)/60.
    return {"version":2,"id":id,"name":["Комбо 1 · передняя рука","Комбо 2 · задняя рука","Комбо 3 · нога"][index],"kind":"action","training_attack":true,"duration":float(last-first)/60.,"fps":60,"easing":clip.easing,"loop":false,"keys":keys,"goals":[],"events":[marker]}

static func document(id:String)->Dictionary:
    var saved:Dictionary=Asset.read(Asset.FOLDER+id+".json")
    if saved.get("id")==id and saved.get("training_attack",false) and Asset.problem(saved)=="":return Asset.normalise(saved)
    return default_doc(id)

# Full source FK, including root and kicking leg. No generic stance solver
# may overwrite the original attack choreography.
static func intent(d:Dictionary,time:float,rig,_feet:Array,entry:Dictionary={})->Dictionary:
    var p:Dictionary=Motion.sample(d,clampf(time/float(d.duration),0.,1.))
    if not entry.is_empty():
        p=Clips.blend_pose(entry,p,smoothstep(0.,.10,time))
    var toes:Array=Motion.toes(rig,p)
    var paths:Array=[]
    for i in 2:
        paths.append({"toe":toes[i],"pitch":p.angles["foot_pitch_"+Motion.SIDES[i]],"stance":absf(toes[i].y)<.5})
    return {"pose":p,"paths":paths}

static func apply(walker,value:Dictionary)->void:
    walker.pose=value.pose
    walker.paths=value.paths
    walker.rig.evaluate(walker.pose)
