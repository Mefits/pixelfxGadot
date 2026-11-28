extends SceneTree
const W=preload("res://lab/combat_study_004/world.gd")
const Air=preload("res://lab/combat_study_004/air.gd")
const View=preload("res://lab/combat_study_004/view.gd")
const TICKS:int=132
var view=View.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func run_trace(name:String,gap:float=26.,mode:int=2,mirror:bool=false,guard:bool=false,capture:bool=false)->Dictionary:
    var w=W.new(gap,true,mode)
    var states:Array=[]
    var logs:Array=[]
    var inputs:Array=[]
    var hud:Array=[]
    var min_gap:float=gap
    var peak:Array=[0.,0.]
    var airborne_ticks:Array=[0,0]
    var max_follow:int=0
    var who:int=1 if mirror else 0
    for t in TICKS:
        var action:String=""
        match name:
            "dash":action="dash" if t==8 else ("jab" if t==18 else "")
            "mixed_ground":action="jab" if t==8 else ("dash" if t==29 else ("pulse" if t==43 else ("launch" if t==56 else "")))
            "air","mirror","blocked","miss":
                action="launch" if t==8 else ("chase" if t==22 else ("air_cross" if t==26 else ("air_pulse" if t==35 else ("slam" if t==44 else ""))))
            "slam":action="launch" if t==8 else ("chase" if t==22 else ("air_cross" if t==26 else ("slam" if t==35 else "")))
            "late":action="launch" if t==8 else ("chase" if t==70 else "")
            "neutral_air":action="chase" if t==8 else ("air_cross" if t==20 else "")
            "spam":
                action=["launch","chase","air_cross","air_pulse","slam","dash"][int(t/3)%6] if t%3==0 else ""
        var a:Dictionary={"action":action}
        var b:Dictionary={"guard":guard}
        var pair:Array=[b,a] if mirror else [a,b]
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        var g:float=w.root_x(1)-w.root_x(0)
        min_gap=minf(min_gap,g)
        check(g>=W.PUSH_GAP-.0001,"pushbox")
        for i in 2:
            var s:Dictionary=w.actors[i]
            peak[i]=maxf(peak[i],-float(s.y))
            if w.airborne(i):airborne_ticks[i]+=1
            max_follow=maxi(max_follow,int(s.follow_left))
            check(float(s.y)<=.0001 and is_finite(float(s.y)) and is_finite(float(s.x)),"finite floor")
        for ev in w.events:
            if ev.attack in Air.MOVES and ev.result=="hit":
                check(w.airborne(ev.attacker) and w.airborne(ev.target),"air hits both airborne")
        hud.append({"hp":[w.actors[0].hp,w.actors[1].hp],"action":w.actors[who].action,"gap":g,"height":[-float(w.actors[0].y),-float(w.actors[1].y)],"stun":w.actors[1-who].stun,"events":w.events.duplicate(true),"freeze":w.freeze})
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%s-%03d.png"%[name,t]))==OK,"save")
    var final:PackedByteArray=w.save()
    var result:Dictionary={"starts":w.starts.duplicate(true),"contacts":w.contacts.duplicate(true),"links":w.links.duplicate(true),"hp":[w.actors[0].hp,w.actors[1].hp],"pursuits":w.pursuits.duplicate(true),"air_hits":w.air_hits.duplicate(true),"slams":w.slams.duplicate(true),"juggles":w.juggle_events.duplicate(true),"landings":w.landings.duplicate(true),"min_gap":min_gap,"peak_height":peak,"airborne_ticks":airborne_ticks,"max_follow":max_follow}
    check(not w.airborne(0) and not w.airborne(1),"finite flight "+name)
    for at in [8,17,22,26,31,35,44,57,80,110]:
        w.restore(states[at])
        for t in range(at,TICKS):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==logs[t],"replay events "+name)
            if t+1<TICKS:check(w.save()==states[t+1],"replay state "+name)
        check(w.save()==final,"replay final "+name)
    var ids:Dictionary={}
    for ev in result.contacts:
        check(not ids.has(ev.id),"unique event")
        ids[ev.id]=true
    if capture:
        var f:=FileAccess.open(out.path_join("hud_"+name+".json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(hud))
        f.close()
    return result

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null:
        push_error("native raster required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var dash:Dictionary=run_trace("dash",38.,2,false,false,true)
    var ground:Dictionary=run_trace("mixed_ground",26.,2,false,false,true)
    var air:Dictionary=run_trace("air",26.,2,false,false,true)
    var slam:Dictionary=run_trace("slam",26.,2,false,false,true)
    var mirror:Dictionary=run_trace("mirror",26.,2,true)
    var blocked:Dictionary=run_trace("blocked",26.,2,false,true)
    var miss:Dictionary=run_trace("miss",80.)
    var late:Dictionary=run_trace("late")
    var neutral:Dictionary=run_trace("neutral_air")
    check(dash.min_gap>=Air.GAP-.0001 and dash.min_gap<30.,"bounded dash travel")
    check(dash.hp==[100,92],"dash followup real hit")
    check(ground.min_gap>=Air.GAP-.0001,"no carry through after dash")
    check(air.pursuits.size()==1 and air.peak_height[0]>5. and air.peak_height[1]>8.,"chase after launch")
    check(not air.air_hits.is_empty(),"actual air contact")
    check(slam.pursuits.size()==1 and not slam.air_hits.is_empty(),"slam route contact")
    check(air.juggles.size()<=1 and slam.juggles.size()<=1,"one juggle per launch")
    check(air.landings.size()==2 and slam.landings.size()==2,"both land")
    check(mirror.hp==[air.hp[1],air.hp[0]] and mirror.air_hits.size()==air.air_hits.size(),"mirror")
    check(blocked.pursuits.is_empty() and blocked.hp==[100,100],"block no pursuit")
    check(miss.pursuits.is_empty() and miss.hp==[100,100],"whiff no pursuit")
    check(late.pursuits.is_empty() and neutral.pursuits.is_empty(),"no late or neutral pursuit")
    for mode in 3:
        var route:Dictionary=run_trace("air",26.,mode)
        var spam:Dictionary=run_trace("spam",26.,mode)
        check(route.pursuits.size()==1,"profile chase")
        check(route.max_follow<=Air.FOLLOW_TICKS,"bounded follow")
        metrics[str(mode)]={"route":route,"spam":spam}
    metrics.merge({"dash":dash,"mixed_ground":ground,"air":air,"slam":slam,"mirror":mirror,"block":blocked,"miss":miss,"late":late,"neutral_air":neutral,"failures":failures})
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_004 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
