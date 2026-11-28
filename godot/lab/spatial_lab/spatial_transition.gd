extends RefCounted
## Opt-in transition adapter. Explicit caller-owned contact schedule.
## Rejected support freezes accepted state and time; caller may release a
## contact or select a different target, never silently teleport.
const FK=preload("res://lab/spatial_lab/spatial_fk.gd")
const Entry=preload("res://lab/spatial_lab/spatial_motion_entry.gd")
const Support=preload("res://lab/spatial_lab/spatial_support.gd")
var rig=FK.new()
var desired=FK.new()
var support=Support.new()
var current:Dictionary={}
var previous:Dictionary={}
var boundary
var age:int=0
var duration:int=0

func seed(r,pose:Dictionary,prior:Dictionary={},contact_state=null)->void:
    current=Entry.sample(r,pose,contact_state)
    previous=(current if prior.is_empty() else prior).duplicate(true)
    Entry.write_exact(rig,current)
    support.contacts=current.contacts.duplicate(true)
    boundary=null
    age=0
    duration=0

func command(ticks:int)->void:
    assert(not current.is_empty() and ticks>0)
    boundary=Entry.new(current,previous)
    support.contacts=boundary.contacts.duplicate(true)
    duration=ticks
    age=0

# Change contact mode from the last accepted world pose, not an incoming clip.
func contact(side:String,mode:int)->void:
    support.capture(rig,current.pose,side,mode)
    current.contacts=support.contacts.duplicate(true)

func step(target:Dictionary,max_shift:float=8.)->Dictionary:
    assert(boundary!=null)
    var p:Dictionary=boundary.blend(desired,target,age,duration)
    if age==0:
        # Command boundary must reproduce current solved state verbatim.
        Entry.write_exact(rig,boundary.current)
        current=Entry.sample(rig,p,support)
        age+=1
        return {"accepted":true,"pose":p,"entry":true,"root_shift":Vector3.ZERO,"max_anchor_error":0.}
    var result:Dictionary=support.resolve_evaluated(rig,desired,max_shift)
    if not result.accepted:return result
    previous=current.duplicate(true)
    current=Entry.sample(rig,p,support)
    age+=1
    result.pose=p
    result.entry=false
    return result

func checkpoint()->Dictionary:
    var state:Dictionary={"current":current,"previous":previous,"age":age,"duration":duration,"contacts":support.contacts,"last_yaw":support.last_yaw,"boundary":{}}
    if boundary!=null:state.boundary={"current":boundary.current,"previous":boundary.previous}
    return state.duplicate(true)

func load_checkpoint(state:Dictionary)->void:
    var s:Dictionary=state.duplicate(true)
    current=s.current
    previous=s.previous
    age=s.age
    duration=s.duration
    support.contacts=s.contacts
    support.last_yaw=s.last_yaw
    boundary=null if s.boundary.is_empty() else Entry.new(s.boundary.current,s.boundary.previous)
    if not current.is_empty():Entry.write_exact(rig,current)
