extends RefCounted
## Small reversible research values, not final frame data.
const EXTRA={"pulse":{"damage":10,"hitstun":16,"blockstun":9,"freeze":4,"reach":18.,"push":1.35},"dash":{"damage":0,"hitstun":0,"blockstun":0,"freeze":0},"launch":{"damage":12,"hitstun":27,"blockstun":9,"freeze":4,"vy":-2.7,"push":.45}}
const ALL=["jab","cross","kick","pulse","dash","launch"]
const DASH_MARK:int=10
const DASH_DURATION:int=18
const GRAVITY:float=.24

static func permits(mode:int,source:String,target:String,result:String,used:Array,remaining:int,age:int,marker:int)->bool:
    if remaining<=0 or age<=marker or source==target or used.has(target) or not target in ALL:return false
    if source=="dash":
        if result!="ready":return false
        return target=="jab" if mode==0 else (target in ["jab","cross","launch"] if mode==1 else true)
    if result!="hit":return false
    if mode==0:return false
    if mode==1:
        return {"jab":["pulse","dash"],"cross":["pulse","launch"],"kick":[],"pulse":["dash"],"launch":[]}.get(source,[]).has(target)
    return true
