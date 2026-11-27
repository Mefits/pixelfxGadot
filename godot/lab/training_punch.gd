extends RefCounted
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const IDS=["train_jab_series"]

static func default_doc(id:String)->Dictionary:
    # Reuse accepted Astra jab angles, source times and original contact.
    # The original jab ends in preparation of the next rear-hand punch.
    # Keep its near-hand punch and retraction, then add a guard exit.
    # The original source JSON is not modified.
    var source:Dictionary=Asset.read(Asset.DIR+"jab.json")
    var base:Dictionary=Motion.document("walk_idle").keys[0]
    var keys:Array=[]
    var last_source:float=26./60.
    for k in source.keys:
        if float(k.t)>last_source+.00001:break
        var pose:Dictionary={"angles":base.angles.duplicate(true),"root":base.root.duplicate()}
        pose.angles.merge(k.angles,true)
        var root:Array=k.get("root",[0.,0.])
        pose.root[0]+=float(root[0])
        pose.root[1]+=float(root[1])
        keys.append(Motion.key(float(k.t),pose))
    var duration:float=.60
    keys.append(Motion.key(duration,{"angles":base.angles,"root":base.root}))
    keys[-1].easing="smooth"
    return {"version":2,"id":id,"name":"Джеб · серия ×3","kind":"action","training_attack":true,"duration":duration,"fps":60,"easing":source.get("easing","linear"),"loop":false,"keys":keys,"goals":[],"events":[source.events[0].duplicate(true)]}

static func document(id:String)->Dictionary:
    var saved:Dictionary=Asset.read(Asset.FOLDER+id+".json")
    if saved.get("id")==id and saved.get("training_attack",false) and Asset.problem(saved)=="":return Asset.normalise(saved)
    return default_doc(id)

static func intent(d:Dictionary,time:float,rig,feet:Array,entry:Dictionary={})->Dictionary:
    var p:Dictionary=Motion.sample(d,clampf(time/float(d.duration),0.,1.))
    if not entry.is_empty():
        p=Clips.blend_pose(entry,p,smoothstep(0.,.065,time))
    var paths:Array=[]
    for i in 2:
        var side:String=Motion.SIDES[i]
        paths.append({"toe":Grid.point(feet[i]),"pitch":Grid.scalar(float(p.angles["foot_pitch_"+side])),"stance":true})
    return {"pose":p,"paths":paths}
