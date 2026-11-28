extends SceneTree
const W=preload("res://lab/aura_study_003/world.gd")
const V=preload("res://lab/aura_study_003/view.gd")
const G=preload("res://lab/aura_study_003/fist_geometry.gd")
const T=preload("res://lab/aura_study_003/trace.gd")
var failures:Array[String]=[]
var metrics:Dictionary={}
var view=V.new()
var output:String
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func p95(a:Array)->int:
    if a.is_empty():return -1
    a.sort()
    return int(a[mini(a.size()-1,floori(a.size()*.95))])
func trace(gap:float,variant:int,scenario:String,mirror:bool=false,capture:String="",replay:bool=false)->Dictionary:
    var w=W.new(gap,variant)
    view.reset()
    var history:Array=[]
    var events:Array=[]
    var inputs:Array=[]
    var heights:Array=[]
    var sim:Array=[]
    var renders:Array=[]
    var aura:Array=[]
    var peak:float=0.
    var source:int=1 if mirror else 0
    var target:int=1-source
    var initial:float=w.root_x(target)
    var travel:float=0.
    var hit_tick:int=-1
    var flight_tick:int=-1
    var stopped:bool=true
    for t in T.TICKS:
        var pair:Array=T.commands(t,scenario,mirror)
        if replay:
            history.append(w.save())
            inputs.append(pair)
        var start:int=Time.get_ticks_usec()
        w.step(pair[0],pair[1])
        sim.append(Time.get_ticks_usec()-start)
        if replay:events.append(w.events.duplicate(true))
        if float(w.actors[target].y)<0. and flight_tick<0:flight_tick=t
        peak=maxf(peak,-float(w.actors[target].y))
        travel=maxf(travel,(w.root_x(target)-initial)*w.facing(source))
        heights.append(float(w.actors[target].y))
        for ev in w.events:
            if ev.attack==W.ATTACK and ev.attacker==source and ev.result=="hit":hit_tick=t
        if not capture.is_empty():
            var before:PackedByteArray=w.save()
            start=Time.get_ticks_usec()
            var im:Image=view.render(w)
            renders.append(Time.get_ticks_usec()-start)
            aura.append(view.aura_us)
            check(im!=null,"native render")
            check(before==w.save(),"render isolated")
            if im!=null:check(im.save_png(output.path_join("%s-%03d.png"%[capture,t]))==OK,"png")
    var end:PackedByteArray=w.save()
    if replay:
        for at in [13,18,25,35,50,75]:
            w.restore(history[at])
            for t in range(at,T.TICKS):
                w.step(inputs[t][0],inputs[t][1])
                check(w.events==events[t],"event replay")
                if t+1<T.TICKS:check(w.save()==history[t+1],"snapshot replay")
            check(w.save()==end,"final replay")
    var relevant:Array=[]
    var ids:Dictionary={}
    for e in w.contacts:
        check(not ids.has(e.id),"unique contact")
        ids[e.id]=true
        if e.attacker==source and e.attack==W.ATTACK:relevant.append(e)
    stopped=absf(float(w.actors[target].push_v))<.001 and float(w.actors[target].y)==0.
    return {"contacts":relevant,"all_contacts":w.contacts,"hp":[w.actors[0].hp,w.actors[1].hp],"target_hp":w.actors[target].hp,"impulses":w.impulses,"landings":w.landings,"travel":travel,"peak_height":peak,"hit_tick":hit_tick,"flight_tick":flight_tick,"frozen_ticks":w.frozen_ticks,"stopped":stopped,"sim_p95_us":p95(sim),"render_p95_us":p95(renders),"aura_p95_us":p95(aura)}
func result_is(x:Dictionary,kind:String)->bool:
    return x.contacts.size()==1 and x.contacts[0].result==kind
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null or view.native_aura==null:
        push_error("native body/aura and output required")
        quit(2)
        return
    output=args[0]
    DirAccess.make_dir_recursive_absolute(output)
    check(absf(G.sweep(Vector2(-20,0),Vector2(20,0),5.,5.)-.375)<.00001,"sweep analytic")
    check(G.sweep(Vector2(-20,10),Vector2(20,10),5.,5.)<0.,"sweep miss")
    # Same stand-off gap for all variants. Require that an ordinary cross
    # cannot reach it; no movement or target snap to manufacture the hit.
    var gap:float=-1.
    var probes:Array=[]
    for d in [52.,50.,48.,46.,44.,42.]:
        var base:Dictionary=trace(d,1,"control")
        var hits:Array=[]
        var good:bool=base.target_hp==100
        for i in 3:
            var x:Dictionary=trace(d,i,"hit")
            hits.append(x)
            good=good and result_is(x,"hit")
        probes.append({"gap":d,"control_hp":base.target_hp,"hits":hits})
        if good and gap<0.:gap=d
    check(gap>0.,"common stand-off gap beyond human punch")
    if gap<0.:gap=44.
    metrics.gap=gap
    metrics.probes=probes
    for i in 3:
        var name:String=G.TIMINGS[i].name
        var hit:Dictionary=trace(gap,i,"hit",false,name+"_hit",true)
        var miss:Dictionary=trace(T.MISS_GAP,i,"miss",false,name+"_miss",true)
        var block:Dictionary=trace(gap,i,"block",false,"",true)
        var mirror:Dictionary=trace(gap,i,"hit",true,"",true)
        var trade:Dictionary=trace(gap,i,"trade",false,"",true)
        var moving:Dictionary=trace(gap,i,"moving",false,"",true)
        check(result_is(hit,"hit") and hit.target_hp==100-G.DAMAGE and hit.all_contacts.size()==1,"single hit "+name)
        check(hit.impulses.size()==1 and hit.travel>35. and hit.peak_height>5. and hit.landings.size()==1 and hit.stopped,"flight landing and stop "+name)
        check(hit.flight_tick>hit.hit_tick and hit.frozen_ticks==G.TIMINGS[i].freeze,"hitstop before launch "+name)
        check(result_is(miss,"miss") and miss.target_hp==100 and miss.impulses.is_empty(),"miss "+name)
        check(result_is(block,"block") and block.target_hp==100 and block.impulses.is_empty(),"block "+name)
        check(mirror.target_hp==hit.target_hp and absf(mirror.travel-hit.travel)<.01,"mirror "+name)
        check(trade.hp==[100-G.DAMAGE,100-G.DAMAGE] and trade.impulses.size()==2,"trade "+name)
        check(not moving.contacts.is_empty(),"moving target "+name)
        metrics[name]={"hit":hit,"miss":miss,"block":block,"mirror":mirror,"trade":trade,"moving":moving}
    metrics.failures=failures
    var f:=FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("AURA_STUDY_003 ",JSON.stringify({"failures":failures,"gap":gap,"sharp":metrics.sharp.hit,"balanced":metrics.balanced.hit,"heavy":metrics.heavy.hit}))
    quit(0 if failures.is_empty() else 1)
