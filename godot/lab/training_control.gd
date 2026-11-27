extends RefCounted
const Punch=preload("res://lab/training_punch.gd")
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const BAG_X:float=34.
const BAG_RADIUS:float=6.
const BAG_TOP:float=-45.
const BAG_BOTTOM:float=-13.
const MAX_CHAIN:int=3
var walker
var docs:Dictionary={}
var active:int=0
var age:int=0
var queued:int=0
var ticks:int=0
var chain:int=0
var last_chain:int=0
var starts:Array=[]
var strikes:int=0
var hits:int=0
var misses:int=0
var hit_flash:int=0
var bag_sway:float=0.
var result:String="—"
var feet:Array=[]
var entry:Dictionary={}
var previous_tip:=Vector2.ZERO
var fired:bool=false

func _init(overrides:Dictionary={}):
    walker=Walk.new()
    var jab:Dictionary=overrides.get(1,Punch.document(Punch.IDS[0]))
    for i in 3:docs[i+1]=jab
    # Idle starts at once, not after a hidden warm-up.
    walker.transition_age=walker.STOP_TICKS+3

func press(key:int=1)->bool:
    if key!=1:return false
    if active==0:
        queued=0
        begin(1,1)
        return true
    # Each fresh press buys exactly one future strike. Fast 1,1,1
    # is valid; no repeated/held input or extra stage can overflow.
    if active+queued<MAX_CHAIN:
        queued+=1
        return true
    return false

func begin(key:int,count:int)->void:
    active=key
    age=0
    fired=false
    chain=count
    starts.append(key)
    entry=walker.pose.duplicate(true)
    feet=Motion.toes(walker.rig,walker.pose)
    walker.direction=0
    previous_tip=tip(str(docs[key].events[0].anchor))
    result="Джеб "+str(key)

func tip(anchor:String)->Vector2:
    var wrist:Vector2=walker.rig.point(anchor)
    var elbow:Vector2=walker.rig.point(anchor.replace("hand_","elbow_"))
    return wrist+(wrist-elbow).normalized()*2.55+Vector2.RIGHT*walker.x

func contact(a:Vector2,b:Vector2)->bool:
    # Fixed training target. Visual sway never changes its collision shape.
    var closest:Vector2=Geometry2D.get_closest_point_to_segment(Vector2(BAG_X,clampf(b.y,BAG_TOP,BAG_BOTTOM)),a,b)
    # Segment vs vertical capsule axis (distance minimized along the sweep).
    for i in 9:
        var p:Vector2=a.lerp(b,float(i)/8.)
        if p.distance_to(Vector2(BAG_X,clampf(p.y,BAG_TOP,BAG_BOTTOM)))<=BAG_RADIUS+1.5:return true
    return closest.distance_to(Vector2(BAG_X,clampf(closest.y,BAG_TOP,BAG_BOTTOM)))<=BAG_RADIUS+1.5

func step(move:int)->void:
    ticks+=1
    hit_flash=maxi(0,hit_flash-1)
    bag_sway=move_toward(bag_sway,0.,.32)
    if active==0:
        if move>0 and walker.x>=BAG_X-BAG_RADIUS-9.:move=0
        walker.step(move)
        return
    var d:Dictionary=docs[active]
    var duration:int=roundi(float(d.duration)*60.)
    age+=1
    var time:float=minf(float(age)/60.,float(d.duration))
    walker.set_intent(Punch.intent(d,time,walker.rig,feet,entry))
    var current:Vector2=tip(str(d.events[0].anchor))
    var marker:int=ceili(float(d.events[0].t)*60.)
    var window_start:int=maxi(1,marker-3)
    var window_end:int=mini(duration,marker+2)
    if not fired and age>=window_start:
        if contact(previous_tip,current):
            fired=true
            strikes+=1
            hits+=1
            hit_flash=7
            bag_sway=4.5
            result="Попадание "+str(active)
        elif age>=window_end:
            fired=true
            strikes+=1
            misses+=1
            result="Промах "+str(active)
    previous_tip=current
    # Preserve the source strike and its retraction. The next accepted
    # press cancels only the final guard recovery, not the contact.
    var link:int=maxi(window_end+1,ceili(duration*.78))
    if queued>0 and active<MAX_CHAIN and age>=link and fired:
        queued-=1
        begin(active+1,chain+1)
        return
    if age>=duration:
        last_chain=chain
        active=0
        queued=0
        chain=0
        walker.capture_transition()
        walker.direction=0
