extends RefCounted
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Clips=preload("res://addons/creature/clips.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
const IDS=["train_jab","train_cross","train_hook"]

static func default_doc(id:String)->Dictionary:
    var base:Dictionary=Motion.document("walk_idle").keys[0]
    var index:int=IDS.find(id)
    var duration:float=[.38,.46,.52][index]
    var impact:float=[.13,.18,.23][index]
    var side:String="far" if index==1 else "near"
    var other:String="near" if index==1 else "far"
    var p:Dictionary={"angles":base.angles.duplicate(true),"root":base.root.duplicate()}
    var wind:Dictionary=p.duplicate(true)
    wind.angles.chest-=3. if index==0 else 8.
    wind.angles["shoulder_"+side]+=10. if index==0 else 20.
    wind.angles["elbow_"+side]-=8.
    var hit:Dictionary=p.duplicate(true)
    hit.root[0]+=1. if index==0 else 2.
    hit.angles.chest+=6. if index==0 else 11.
    hit.angles.head-=6. if index==0 else 11.
    hit.angles.shoulder_turn=12. if index!=1 else 78.
    # Side-specific rest angles differ. Straight near/far punches and
    # a shorter bent-arm hook, all aimed at roughly chest/head height.
    hit.angles["shoulder_"+side]=[-86.,-62.,-54.][index]
    hit.angles["elbow_"+side]=[-25.,4.,-100.][index]
    hit.angles["shoulder_"+other]-=4.
    hit.angles["elbow_"+other]-=3.
    var recover:Dictionary=Clips.blend_pose(hit,p,.65)
    var keys:Array=[Motion.key(0.,p),Motion.key(impact*.45,wind),Motion.key(impact,hit),Motion.key(impact+.045,hit),Motion.key(duration*.75,recover),Motion.key(duration,p)]
    return {"version":2,"id":id,"name":["1 · Джеб","2 · Прямой задней","3 · Боковой"][index],"kind":"action","training_attack":true,"duration":duration,"fps":60,"easing":"smooth","loop":false,"keys":keys,"goals":[],"events":[{"t":impact,"kind":"strike","anchor":"hand_"+side}]}

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
