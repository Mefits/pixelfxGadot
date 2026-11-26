extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Goals=preload("res://lab/authoring/goals.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Editor=preload("res://lab/authoring/editor.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
var failed:=false
func check(ok:bool,msg:String):
    if not ok:
        failed=true
        push_error(msg)

func command(d,t:int,scale:int)->Dictionary:
    var f:=float(t)/scale
    if d.kind=="gait":return {"speed":1. if f<24 else (d.speed if f<132 else 0.)}
    return {"speed":0.,"action":d.id if t==30*scale else ""}

func _initialize():call_deferred("run")
func run():
    var args:=OS.get_cmdline_user_args()
    var hz:int=int(args[0]) if args.size() else 60
    var digest:=HashingContext.new()
    digest.start(HashingContext.HASH_SHA256)
    var scale:int=hz/60
    for id in Asset.IDS:
        var d:=Asset.read(Asset.DIR+id+".json")
        check(Asset.problem(d)=="","document")
        var base=Asset.player(d,hz)
        var target_tick:=50*scale
        if d.kind=="gait":
            for t in range(132*scale):
                base.step(command(d,t,scale))
                if t>65*scale and not base.paths[0].stance and not base.paths[1].stance:
                    target_tick=t
                    break
        else:
            for t in range(target_tick+1):base.step(command(d,t,scale))
        var clock:String="swing_near" if d.kind=="gait" else "action"
        var center:float=Goals.phase(base,clock) if d.kind=="gait" else float(base.age-1)/(base.bank[id].frames.size()-1)
        var orig:Vector2=base.rig.point("hand_near")
        var goal:=(orig+Vector2(-3.,-5.)).snapped(Vector2.ONE/64.)
        d.goals=[{"joint":"hand_near","xy":[goal.x,goal.y],"clock":clock,"center":center,"weight":1.,"priority":2,"width":.22}]
        d.goals.append(d.goals[0].duplicate(true))
        d.goals[1].xy=[90,30]
        d.goals[1].priority=1
        var corrected=Asset.player(d,hz)
        var plain:Dictionary=d.duplicate(true)
        plain.goals=[]
        base=Asset.player(plain,hz)
        var snap:PackedByteArray
        var event_count:=0
        var costs:Array=[]
        var old_cost:Array=[]
        var states:Array=[]
        for t in range((220 if id=="sprint" else 92)*scale):
            var cmd:=command(d,t,scale)
            if t==target_tick:
                snap=corrected.save()
                cmd.hurt_center=goal+Vector2.RIGHT*(base.gait.travel+(0. if base.stopped else base.speed/scale))
                cmd.radius=1.5
            var before:=Time.get_ticks_usec()
            base.step(cmd)
            old_cost.append(Time.get_ticks_usec()-before)
            before=Time.get_ticks_usec()
            corrected.step(cmd)
            costs.append(Time.get_ticks_usec()-before)
            var state:PackedByteArray=corrected.save()
            states.append(state)
            digest.update(state)
            digest.update(var_to_bytes(corrected.events))
            for i in 2:
                var side:String=Leg.SIDES[i]
                check(Leg.valid(corrected.final_pose,side),"anatomy")
                if base.paths[i].stance:check(base.anchors["foot_"+side]==corrected.anchors["foot_"+side],"support")
            if t==target_tick:
                check(corrected.rig.point("hand_near").distance_to(goal)<orig.distance_to(goal)*.65,"target "+id+" "+str(corrected.rig.point("hand_near").distance_to(goal)))
                check(corrected.goal_report.hand_near.index==0,"priority")
                if id=="jab":check(corrected.health==95 and base.health==100,"edited contact "+str([corrected.health,base.health]))
            event_count+=corrected.events.size()
        check(event_count==d.get("events",[]).size(),"event count")
        corrected.restore(snap)
        for t in range(target_tick,mini(target_tick+12,states.size())):
            var cmd:=command(d,t,scale)
            if t==target_tick:
                var next_state:Array=bytes_to_var(states[t])
                cmd.hurt_center=goal+Vector2.RIGHT*next_state[3].travel
                cmd.radius=1.5
            corrected.step(cmd)
            check(corrected.save()==states[t],"restore "+id)
        costs.sort()
        old_cost.sort()
        print(id," @",hz," p95 base/goals us ",old_cost[int(.95*old_cost.size())],"/",costs[int(.95*costs.size())]," tick ",target_tick)
    # Interrupt a driven attack with a different data-only program before its marker.
    var g:=Asset.read(Asset.DIR+"sprint.json")
    var j:=Asset.read(Asset.DIR+"jab.json")
    var f:=Asset.read(Asset.DIR+"feint.json")
    var ensemble=Asset.ensemble(g,[j,f],hz)
    for t in range(100*scale):
        var c={"speed":1.85}
        if t==60*scale:c.action="jab"
        if t==68*scale:c.action="feint"
        ensemble.step(c)
        check(ensemble.events.is_empty(),"cancel future marker")
        if t==68*scale:check(ensemble.action=="feint","interrupt")
    # A release track is compiled through the existing 091 author-foot solver.
    var source:Dictionary=Asset.read(Asset.FIX+"highkick051c2_C.json").payload.clip
    var kick={"version":1,"id":"released_kick","name":"kick","kind":"action","duration":.5,"goals":[],"keys":[],"events":[{"t":.25,"kind":"strike","anchor":"foot_far"}],"release":{"far":[0.,.25,.65,1.]}}
    for i in range(31):
        kick.keys.append({"t":i/60.,"angles":source.keys[23+i].pose.angles})
    check(Asset.problem(kick)=="","leg document")
    var kicker=Asset.player(kick,hz)
    var foot_marker:=false
    for t in range(55*scale):
        kicker.step({"speed":0.,"action":"released_kick" if t==20*scale else ""})
        if t==35*scale:
            foot_marker=kicker.events.size()==1 and kicker.events[0][3]=="foot_far"
            check(kicker.released.has("far") and not kicker.paths[1].stance,"authored swing")
    check(foot_marker,"foot event")
    # An impossible planted toe cannot move the support; a hand outside
    # the reach disk must report the clamp while preserving bone lengths.
    g.goals=[{"joint":"foot_near","xy":[100,-90],"clock":"cycle","center":0.,"width":1.,"priority":9,"weight":1.},
        {"joint":"hand_near","xy":[120,-110],"clock":"cycle","center":0.,"width":1.,"priority":9,"weight":1.}]
    var blocked=Asset.player(g,hz)
    blocked.step({"speed":1.})
    check(blocked.goal_report.foot_near.reason=="стопа в опоре","support priority")
    check(blocked.goal_report.hand_near.reason=="предел длины руки","reach diagnostic")
    check(blocked.rig.point("elbow_near").distance_to(blocked.rig.point("hand_near"))<10.,"arm length bound")
    print("TRACE ",digest.finish().hex_encode())
    quit(1 if failed else 0)
