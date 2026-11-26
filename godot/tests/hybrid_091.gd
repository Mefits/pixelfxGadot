extends SceneTree
const History=preload("res://lab/hybrid091/history.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Old=preload("res://lab/natural_arms_090.gd")
const Depth=preload("res://lab/arm_depth_090.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const FIX="res://tests/fixtures/body_raster/full_058/"
const CHANNELS=["chest","head","shoulder_turn","shoulder_near","elbow_near","shoulder_far","elbow_far"]
var cfg={"width":288,"height":240,"origin":[136,195],"density":3,"ink":0xff000000,"outline":3,
    "light":[-.48,-.64,.6],"seams":false,"materials":[
    [0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],
    [0xffa09d74,0xff827d50,0xff656139,0xff4a4628],
    [0xff655a4c,0xff50473b,0xff3c342c,0xff29231e]]}
var run_clip:Dictionary
var bank:Dictionary
var guard:Dictionary
var rate:int
var failed:=false
var body=Body.new(2)
func require(ok:bool,message:String)->void:
    if not ok and not failed:
        push_error(message)
        failed=true

func command(t:int)->Dictionary:
    var frame:=float(t)*60./rate
    var c={"speed":1. if frame<30 else (1.85 if frame<112 else 0.),"hurt_center":Vector2(228,-33),"radius":6.}
    if frame==112:c.action="jab"
    if frame==137:c.action="cross"
    if frame==142:c.impulse=-140.
    return c

func new_player():
    return Kernel.new(Body.make_rig(),run_clip,bank,guard,rate)

func render(r,p,w,raster)->Image:
    var parts:Array=body.make(r.points,p.angles,r.rotations.head)
    Depth.apply(parts,w)
    for i in [0,2,3,8,9]:parts[i].material_id=1
    for i in [5,6,7,11,12,13,15,17]:parts[i].material_id=2
    var result:Dictionary=raster.render(cfg,parts)
    return Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)

func pct(values:Array,f:float):
    var sorted:=values.duplicate()
    sorted.sort()
    return sorted[floori((sorted.size()-1)*f)]

func _initialize():
    var args:=OS.get_cmdline_user_args()
    rate=int(args[0]) if args.size() else 60
    run_clip=JSON.parse_string(FileAccess.get_file_as_string(FIX+"run053a_C.json")).payload.clip
    var clip:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIX+"combo052a2_B.json")).payload.clip
    bank={"jab":Motion.compile(clip,0,38,CHANNELS,rate),"cross":Motion.compile(clip,23,45,CHANNELS,rate)}
    guard=bank.jab.frames[0]
    var k=new_player()
    var ref_rig=Body.make_rig()
    var old=Old.new(ref_rig,run_clip)
    old.polish=true
    var snapshots:Array=[]
    var logs:Array=[]
    var anchors:Dictionary={}
    var errors:float=0.
    var drift:float=0.
    var jumps:float=0.
    var prev:Dictionary={}
    var old_cost:Array=[]
    var new_cost:Array=[]
    var walk_cost:Array=[]
    var replay_cost:Array=[]
    var old_replay_cost:Array=[]
    var old_saves:Array=[]
    var history:=HashingContext.new()
    history.start(HashingContext.HASH_SHA256)
    var marks:Array=[]
    var trace:=PackedStringArray()
    var scale:int=rate/60
    for t in 245*scale:
        snapshots.append(k.save())
        var cmd:=command(t)
        var start:=Time.get_ticks_usec()
        k.step(cmd)
        new_cost.append(Time.get_ticks_usec()-start)
        if t<112*scale:walk_cost.append(new_cost.back())
        var log_bytes:=var_to_bytes(k.events)
        logs.append(log_bytes)
        history.update(snapshots.back())
        history.update(log_bytes)
        var digest:=HashingContext.new()
        digest.start(HashingContext.HASH_SHA256)
        digest.update(snapshots.back())
        digest.update(log_bytes)
        trace.append(digest.finish().hex_encode())
        for ev in k.events:
            marks.append(ev)
            print("MARK ",ev," endpoint ",k.anchors[ev[3]])
        var p:Dictionary=k.final_pose
        for id in k.rig.points:
            if prev.has(id):jumps=maxf(jumps,k.rig.point(id).distance_to(prev[id]))
        prev=k.rig.points.duplicate()
        for i in 2:
            var side:String=Leg.SIDES[i]
            require(Leg.valid(p,side),"leg limit "+str(t))
            var toe:Vector2=k.rig.point("foot_"+side)+IK.toe_vector(p,side)+Vector2.RIGHT*k.gait.travel
            if k.paths[i].stance:
                if anchors.has(side):drift=maxf(drift,toe.distance_to(anchors[side]))
                else:anchors[side]=toe
            else:anchors.erase(side)
        if rate==60 and t<112:
            old_saves.append(old.snapshot())
            start=Time.get_ticks_usec()
            old.advance(k.speed)
            var ref:Dictionary=old.sample()
            ref_rig.evaluate(ref.pose)
            old_cost.append(Time.get_ticks_usec()-start)
            for id in ref_rig.points:errors=maxf(errors,k.rig.point(id).distance_to(ref_rig.point(id)))
    snapshots.append(k.save())
    history.update(snapshots.back())
    require(errors<.005,"baseline joint error "+str(errors))
    require(drift<.015,"stance drift "+str(drift))
    require(k.stopped and k.settle==1. and k.paths[0].stance and k.paths[1].stance,"guard")
    require(marks.size()==2 and marks[0][0]==132*scale and marks[1][0]==146*scale,"cancelled marker")
    require(k.health==95 and marks[0][4] and not marks[1][4],"swept hit and miss")
    if OS.has_environment("HYBRID_TRACE"):
        var file:=FileAccess.open(OS.get_environment("HYBRID_TRACE"),FileAccess.WRITE)
        file.store_string("\n".join(trace))
        if OS.get_environment("HYBRID_TRACE").ends_with("-0.txt"):
            var details:=FileAccess.open(OS.get_environment("HYBRID_TRACE")+".jsonl",FileAccess.WRITE)
            for snapshot in snapshots:
                details.store_line(JSON.stringify(bytes_to_var(snapshot),"",false,true))
    # Discard predicted damage by restoring the pre-contact state. Reapply
    # with a displaced target, then replay the confirmed hit exactly once.
    var replay=new_player()
    # Editor fixture: release only the far foot during a kick; ground the
    # near toe, test a world-space foot marker and cancel during retraction.
    var kick:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIX+"highkick051c2_C.json")).payload.clip
    bank["kick"]=Motion.compile(kick,23,53,CHANNELS,rate,Body.make_rig(),{"far":[23,33,40,53]})
    replay.restore(snapshots.back())
    var near_anchor:Vector2=replay.anchors.foot_near
    var entry_y:float=replay.anchors.foot_far.y
    var highest:=entry_y
    var kick_hit:=false
    for f in range(22*scale):
        var c={"speed":0.,"hurt_center":Vector2(replay.gait.travel+15.,-26.),"radius":12.}
        if f==0:c.action="kick"
        if f==19*scale:c.action="jab"
        if f==20*scale:c.impact={"joint":"hand_far","force":Vector2(-4.,0.),"gain":1.5,"cap":80.}
        replay.step(c)
        require(near_anchor.distance_to(replay.anchors.foot_near)<.015,"kick support")
        require(Leg.valid(replay.final_pose,"far"),"kick anatomy")
        highest=minf(highest,replay.anchors.foot_far.y)
        if not replay.events.is_empty():
            kick_hit=replay.events[0][3]=="foot_far" and replay.events[0][4]
    history.update(replay.save())
    require(entry_y-highest>12. and kick_hit,"released leg contact "+str([highest,kick_hit]))
    var contact:=132*scale
    replay.restore(snapshots[contact])
    var miss:=command(contact)
    miss.hurt_center+=Vector2(80.,0.)
    replay.step(miss)
    require(replay.health==100 and not replay.events[0][4],"corrected miss")
    replay.restore(snapshots[contact])
    replay.step(command(contact))
    require(replay.health==95 and replay.save()==snapshots[contact+1],"corrected hit")
    var session:=History.new(replay,8*scale)
    for n in range(contact+1,contact+9*scale+1):
        var c:=command(n)
        if n==137*scale:c.erase("action")
        require(session.advance(c),"ring advance")
        session.confirm_through(n-6*scale)
    require(session.correct(137*scale,command(137*scale)),"late command")
    require(replay.save()==snapshots[contact+9*scale+1],"ring corrected state")
    for n in range(replay.tick,147*scale+1):
        session.confirm_through(n-5*scale)
        require(session.advance(command(n)),"history capacity")
    var published:=session.confirm_through(replay.tick-1)
    require(published.size()==1 and session.confirm_through(replay.tick-1).is_empty(),"publish once")
    require(not session.correct(contact,miss),"confirmed history immutable")
    # Replace the attack during the first transition.
    replay.restore(snapshots[113*scale])
    var replace:=command(113*scale)
    replace.action="cross"
    var before:Dictionary=replay.pose.angles.duplicate()
    replay.step(replace)
    for channel in CHANNELS:
        require(absf(wrapf(replay.pose.angles[channel]-before[channel],-180.,180.))<.001,"mid-transition discontinuity")
    for t in range(0,245*scale-8,3):
        var start:=Time.get_ticks_usec()
        replay.restore(snapshots[t])
        for n in range(t,t+8):
            replay.step(command(n))
            require(var_to_bytes(replay.events)==logs[n],"replay events "+str(n))
            require(replay.save()==snapshots[n+1],"replay state "+str(n))
        start=Time.get_ticks_usec()
        replay.restore(snapshots[t])
        for n in range(t,t+8):
            replay.step(command(n))
            replay.save()
        replay_cost.append(Time.get_ticks_usec()-start)
        if t+8<old_saves.size():
            start=Time.get_ticks_usec()
            old.restore(old_saves[t])
            for n in range(t,t+8):
                old.advance(old_saves[n+1].velocity)
                ref_rig.evaluate(old.sample().pose)
                old.snapshot()
            old_replay_cost.append(Time.get_ticks_usec()-start)
    print("RESULT ",JSON.stringify({"rate":rate,"sha256":history.finish().hex_encode(),"old_p95_us":pct(old_cost,.95) if old_cost.size() else 0,"gait_p95_us":pct(walk_cost,.95),"tick_p95_us":pct(new_cost,.95),"old_restore_8_gait_p95_us":pct(old_replay_cost,.95) if old_replay_cost.size() else 0,"restore_8_p95_us":pct(replay_cost,.95),"drift":drift,"baseline_error":errors,"peak_joint_delta":jumps,"snapshot_max_bytes":snapshots.map(func(b): return b.size()).max(),"health":k.health}))
    quit(1 if failed else 0)
