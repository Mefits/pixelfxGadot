extends RefCounted
const MOVES=["air_cross","air_pulse","slam"]
const EXTRA={"chase":{"damage":0,"hitstun":0,"blockstun":0,"freeze":0},"air_cross":{"damage":8,"hitstun":16,"blockstun":0,"freeze":3},"air_pulse":{"damage":9,"hitstun":12,"blockstun":0,"freeze":3},"slam":{"damage":14,"hitstun":18,"blockstun":0,"freeze":4}}
const GAP:float=26.
const CHASE_MARK:int=3
const CHASE_DURATION:int=10
const FOLLOW_TICKS:int=20
const JUGGLE_VY:float=-1.4
const SLAM_VY:float=3.8
const LINKS=[
    {"chase":["air_cross"],"air_cross":["slam"],"air_pulse":[],"slam":[]},
    {"chase":["air_cross","air_pulse"],"air_cross":["air_pulse","slam"],"air_pulse":["slam"],"slam":[]},
    {"chase":["air_cross","air_pulse","slam"],"air_cross":["air_pulse","slam"],"air_pulse":["air_cross","slam"],"slam":[]}
]
static func permits(mode:int,source:String,target:String,result:String,used:Array,remaining:int,age:int,marker:int)->bool:
    if remaining<=0 or age<=marker or used.has(target):return false
    if source=="chase":
        return result=="ready" and target in LINKS[mode].chase
    return result=="hit" and target in LINKS[mode].get(source,[])
