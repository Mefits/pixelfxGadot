extends SceneTree
const W=preload("res://lab/combat_study_002/world.gd")
const P=preload("res://lab/combat_study_002/policy.gd")
const View=preload("res://lab/combat_study_001/view.gd")
const TICKS:int=126
var failures:Array[String]=[]
var out:String
var view=View.new()
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func fixture(profile:int,name:String,gap:float=26.,mirror:bool=false,capture:bool=false)->Dictionary:
    var w=W.new(gap,true,profile)
    var states:Array=[]
    var inputs:Array=[]
    var logs:Array=[]
    var hud:Array=[]
    var first_gap:int=-1
    var last_hit:int=-1
    var unlocked:int=0
    var longest:int=0
    var chain:int=0
    var max_locked:int=0
    var current_locked:int=0
    var start_names:Array=[]
    for t in TICKS:
        var action:String=""
        match name:
            "branch","guard","whiff","mirror":
                action="jab" if t==8 else ("kick" if t==29 else ("cross" if t==50 else ""))
            "linear":
                action="jab" if t==8 else ("cross" if t==29 else ("kick" if t==42 else ""))
            "spam":
                action=["jab","cross","kick"][int(t/3)%3] if t%3==0 else ""
            "trade":
                action="jab" if t==8 else ("cross" if t==29 else "")
            "repeat":
                action="jab" if t in [8,29,32] else ""
        var a:Dictionary={"action":action}
        var b:Dictionary={"guard":name=="guard","action":"jab" if name=="trade" and t==8 else ""}
        var pair:Array=[b,a] if mirror else [a,b]
        var attacker:int=1 if mirror else 0
        var defender:int=1-attacker
        # Real pre-tick action availability, excluding global hitstop.
        if w.freeze==0:
            var d:Dictionary=w.actors[defender]
            if d.stun==0 and d.remaining==0 and not d.interrupt:
                if last_hit>=0:unlocked+=1
                current_locked=0
            else:
                current_locked+=1
                max_locked=maxi(max_locked,current_locked)
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        for ev in w.events:
            if ev.attacker==attacker and ev.result=="hit":
                if last_hit<0 or unlocked>0:
                    if last_hit>=0 and first_gap<0:first_gap=unlocked
                    chain=1
                else:chain+=1
                longest=maxi(longest,chain)
                last_hit=t
                unlocked=0
        var s:Dictionary=w.actors[attacker]
        hud.append({"hp":[w.actors[0].hp,w.actors[1].hp],"action":s.action,"remaining":s.remaining,"stun":w.actors[defender].stun,"freeze":w.freeze,"buffer":s.buffer,"links":w.links.size(),"longest":longest,"events":w.events.duplicate(true)})
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%d-%03d.png"%[profile,t]))==OK,"save")
    var final:PackedByteArray=w.save()
    var full:Dictionary={"starts":w.starts.duplicate(true),"links":w.links.duplicate(true),"contacts":w.contacts.duplicate(true),"hp":[w.actors[0].hp,w.actors[1].hp],"frozen_ticks":w.frozen_ticks,"first_response_gap":first_gap,"longest_uninterrupted_hits":longest,"max_locked_nonfreeze_ticks":max_locked}
    for st in w.starts:
        if st[1]==(1 if mirror else 0):start_names.append(st[2])
    full.names=start_names
    # Same-process exact restore across input buffer, hitstop, cancel and
    # the contact after a cancel. Compare states and event stream at each tick.
    for at in [0,8,28,29,32,42,50,65,90]:
        w.restore(states[at])
        for t in range(at,TICKS):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==logs[t],"replay event %d %s %d"%[profile,name,t])
            if t+1<TICKS:check(w.save()==states[t+1],"replay state %d %s %d"%[profile,name,t])
        check(w.save()==final,"replay final")
    var ids:Dictionary={}
    for ev in full.contacts:
        check(not ids.has(ev.id),"unique event ID")
        ids[ev.id]=true
    if capture:
        var f:=FileAccess.open(out.path_join("hud_%d.json"%profile),FileAccess.WRITE)
        f.store_string(JSON.stringify(hud))
        f.close()
    return full

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null:
        push_error("native raster required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    # Exhaustive small policy table, independently of geometry. The actual
    # match below also uses public inputs and native sampled contacts.
    for mode in 3:
        for from in P.MOVES:
            for to in P.MOVES:
                var expected:bool=to in P.LINKS[mode][from]
                check(P.permits(mode,from,to,"hit",[from],8,21,20)==expected,"policy topology")
                check(not P.permits(mode,from,to,"miss",[from],8,21,20),"no whiff cancel")
                check(not P.permits(mode,from,to,"block",[from],8,21,20),"no block cancel")
                check(not P.permits(mode,from,to,"hit",[from,to],8,21,20),"no repeat within chain")
                check(not P.permits(mode,from,to,"hit",[from],8,20,20),"no pre-contact cancel")
        var branch:Dictionary=fixture(mode,"branch",26.,false,true)
        var linear:Dictionary=fixture(mode,"linear")
        var blocked:Dictionary=fixture(mode,"guard")
        var missed:Dictionary=fixture(mode,"whiff",80.)
        var mirror:Dictionary=fixture(mode,"mirror",26.,true)
        var spam:Dictionary=fixture(mode,"spam")
        var repeat:Dictionary=fixture(mode,"repeat")
        var trade:Dictionary=fixture(mode,"trade")
        check(not branch.contacts.is_empty() and branch.contacts[0].result=="hit","first genuine hit")
        check(not linear.links.is_empty() and linear.links[0].to=="cross","linear first link")
        check(blocked.links.is_empty() and blocked.hp==[100,100],"block no cancel")
        check(missed.links.is_empty() and missed.hp==[100,100],"miss no cancel")
        check(repeat.links.is_empty(),"same move no cancel")
        check(trade.links.is_empty(),"trade clears cancel rights")
        check(mirror.hp==[branch.hp[1],branch.hp[0]] and mirror.names==branch.names,"mirror sequence")
        if mode==0:
            check(branch.links.is_empty() or branch.links[0].to!="kick","linear rejects early kick")
        else:
            check(not branch.links.is_empty() and branch.links[0].to=="kick","branch accepts early kick")
        if mode==1:
            for link in branch.links:check(link.from!="kick","B kick terminal")
        # Longest actual hit chain is telemetry, not an invented target or
        # a claim of universal infinites prevention.
        metrics[str(mode)]={"branch":branch,"linear":linear,"guard":blocked,"whiff":missed,"mirror":mirror,"spam":spam,"repeat":repeat,"trade":trade}
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_002 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
