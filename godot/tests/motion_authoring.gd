extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Goals=preload("res://lab/authoring/goals.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Editor=preload("res://lab/authoring/editor.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Clips=preload("res://addons/creature/clips.gd")
const VFX=preload("res://addons/pixelfx/composer/preset.gd")
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
        digest.update(ensemble.save())
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
        digest.update(kicker.save())
        if t==35*scale:
            foot_marker=kicker.events.size()==1 and kicker.events[0][3]=="foot_far"
            check(kicker.released.has("far") and not kicker.paths[1].stance,"authored swing")
    check(foot_marker,"foot event")
    # Legacy U clip import preserves root, easing, loop and non-combat events.
    var old_bank:Dictionary=Clips.defaults()
    var imported:Array=Asset.import_legacy_bank(old_bank,"u",30)
    check(imported.size()>=7,"legacy bank import count")
    var old_strike:Dictionary=old_bank.strike
    var imported_strike:Dictionary={}
    for d in imported:
        if d.id=="u_strike":imported_strike=d
    check(not imported_strike.is_empty(),"legacy strike imported")
    if not imported_strike.is_empty():
        check(imported_strike.fps==30 and imported_strike.easing=="smooth" and imported_strike.loop==false,"legacy clip metadata")
        check(imported_strike.keys[1].root==old_strike.keys[1].pose.root,"legacy root preserved")
        check(imported_strike.events[0].kind=="strike","legacy strike event preserved")
    var old_cast:Dictionary={}
    for d in imported:
        if d.id=="u_cast":old_cast=d
    check(not old_cast.is_empty() and old_cast.events.size()==2,"charge/cast events imported")
    var loop_doc:Dictionary=Asset.legacy_clip_to_action(old_bank.idle,"u_idle","Idle",30)
    check(not loop_doc.is_empty() and loop_doc.loop,"legacy loop imported")
    var loop_player=Asset.player(loop_doc,hz)
    for t in range(loop_player.bank.u_idle.frames.size()*2+2):
        loop_player.step({"speed":0.,"action":"u_idle" if t==0 else ""})
    check(loop_player.action=="u_idle" and loop_player.age<loop_player.bank.u_idle.frames.size(),"looping action wraps")
    var root_doc:Dictionary=Asset.legacy_clip_to_action(old_bank.strike,"u_root","Root",30)
    root_doc.goals=[]
    for key in root_doc.keys:key.root=[-3.,1.]
    var root_player=Asset.player(root_doc,hz)
    var root_baseline:Dictionary=root_doc.duplicate(true)
    for key in root_baseline.keys:key.root=[0.,0.]
    var baseline_player=Asset.player(root_baseline,hz)
    root_player.step({"speed":0.,"action":"u_root"})
    baseline_player.step({"speed":0.,"action":"u_root"})
    check(is_equal_approx(root_player.final_pose.root[0]-baseline_player.final_pose.root[0],-3.),"action root X runtime")
    check(is_equal_approx(root_player.final_pose.root[1]-baseline_player.final_pose.root[1],1.),"action root Y runtime")
    root_doc.events=[{"t":0.,"kind":"vfx","anchor":"hand_near","preset":VFX.demo(0)}]
    check(Asset.problem(root_doc)=="","VFX event schema")
    var vfx_player=Asset.player(root_doc,hz)
    vfx_player.step({"speed":0.,"action":"u_root"})
    check(vfx_player.events.size()==1 and vfx_player.events[0][5]=="vfx" and vfx_player.health==100,"VFX event does not cause damage")
    # An impossible planted toe cannot move the support; a hand outside
    # the reach disk must report the clamp while preserving bone lengths.
    g.goals=[{"joint":"foot_near","xy":[100,-90],"clock":"cycle","center":0.,"width":1.,"priority":9,"weight":1.},
        {"joint":"hand_near","xy":[120,-110],"clock":"cycle","center":0.,"width":1.,"priority":9,"weight":1.}]
    var blocked=Asset.player(g,hz)
    blocked.step({"speed":1.})
    check(blocked.goal_report.foot_near.reason=="стопа в опоре","support priority")
    check(blocked.goal_report.hand_near.reason=="предел длины руки","reach diagnostic")
    check(blocked.rig.point("elbow_near").distance_to(blocked.rig.point("hand_near"))<10.,"arm length bound")
    # A swing-knee edit redirects the free chain without moving its sibling.
    g.goals=[]
    var plain_gait=Asset.player(g,hz)
    var kt:=0
    while kt<135*scale:
        plain_gait.step(command(g,kt,scale))
        var ph:=Goals.phase(plain_gait,"swing_near")
        if kt>62*scale and ph>.35 and ph<.65:break
        kt+=1
    var knee_pos:Vector2=plain_gait.rig.point("knee_near")
    var desired:=(knee_pos+Vector2(2.,-1.)).snapped(Vector2.ONE/64.)
    g.goals=[{"joint":"knee_near","xy":[desired.x,desired.y],"clock":"swing_near","center":Goals.phase(plain_gait,"swing_near"),"width":.2,"weight":1.,"priority":2}]
    var knee_player=Asset.player(g,hz)
    for t in kt+1:
        knee_player.step(command(g,t,scale))
        digest.update(knee_player.save())
    check(knee_player.rig.point("knee_near").distance_to(desired)<knee_pos.distance_to(desired),"swing knee influence")
    check(Leg.valid(knee_player.final_pose,"near"),"free knee limits")
    print("TRACE ",digest.finish().hex_encode())
    quit(1 if failed else 0)
