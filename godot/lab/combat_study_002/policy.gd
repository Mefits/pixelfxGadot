extends RefCounted
## Only the transition topology differs. Same move bank, damage, contact,
## buffer and recovery lengths for all three profiles.
const NAMES=["A Linear","B Branching","C Situational"]
const MOVES=["jab","cross","kick"]
const LINKS=[
    {"jab":["cross"],"cross":["kick"],"kick":[]},
    {"jab":["cross","kick"],"cross":["kick"],"kick":[]},
    {"jab":["cross","kick"],"cross":["jab","kick"],"kick":["jab","cross"]}
]

static func permits(mode:int,from:String,to:String,result:String,used:Array,remaining:int,age:int,marker:int)->bool:
    if remaining<=0 or age<=marker or result!="hit" or from==to or used.has(to):return false
    return LINKS[mode].get(from,[]).has(to)
