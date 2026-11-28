extends SceneTree
const W=preload("res://lab/ability_study_001/world.gd")
const Baseline=preload("res://lab/combat_study_005/world.gd")
const View=preload("res://lab/ability_study_001/view.gd")
const IDS=["energy_bolt","energy_blade","impact_dash"]
const TICKS=120
var view=View.new()
var failures:Array[String]=[]
var output:String
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)

func trace(id:String,gap:float,case:String,mirror:bool=false,capture:String="",replay:bool=false)->Dictionary:
    var w=W.new(gap)
    var history:Array=[]
    var inputs:Array=[]
    var events:Array=[]
    var simulation:Array=[]
    var visual:Array=[]
    var plain_times:Array=[]
    var max_travel:float=0.
    var max_entities:int=0
    var min_gap:float=INF
    var initial:float=w.root_x(0)
    for t in TICKS:
        var a:Dictionary={}
        var b:Dictionary={}
        if t==8:a.action=id
        if case=="block":b.guard=true
        if case=="moving":b.forward=true
        if case=="both" and t==8:b.action=id
        if case=="interrupt":
            a={}
            if t==8:b.action="jab"
            if t==24:a.action=id
        var pair:Array=[b,a] if mirror else [a,b]
        if replay:
            history.append(w.save())
            inputs.append(pair.duplicate(true))
        var start:int=Time.get_ticks_usec()
        w.step(pair[0],pair[1])
        simulation.append(Time.get_ticks_usec()-start)
        if replay:events.append(w.events.duplicate(true))
        max_entities=maxi(max_entities,w.entities.size())
        min_gap=minf(min_gap,w.root_x(1)-w.root_x(0))
        max_travel=maxf(max_travel,w.root_x(0)-initial)
        check(min_gap>=W.PUSH_GAP-.001,"pushbox")
        if not capture.is_empty():
            var before:PackedByteArray=w.save()
            start=Time.get_ticks_usec()
            view.enabled=true
            var im:Image=view.render(w)
            visual.append(Time.get_ticks_usec()-start)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(output.path_join("%s-%03d.png"%[capture,t]))==OK,"png")
            view.enabled=false
            start=Time.get_ticks_usec()
            var plain:Image=view.render(w)
            plain_times.append(Time.get_ticks_usec()-start)
            check(plain!=null and w.save()==before,"VFX off leaves state unchanged")
            view.enabled=true
    var end:PackedByteArray=w.save()
    if replay:
        for at in [9,16,20,30,44,75]:
            w.restore(history[at])
            for t in range(at,TICKS):
                w.step(inputs[t][0],inputs[t][1])
                check(w.events==events[t],"replay events "+id+case)
                if t+1<TICKS:check(w.save()==history[t+1],"replay state "+id+case)
            check(w.save()==end,"replay final "+id+case)
    var ids:Dictionary={}
    var outcomes:Array=[]
    for ev in w.contacts:
        check(not ids.has(ev.id),"unique contact id")
        ids[ev.id]=true
        if ev.attack==id:outcomes.append(ev)
    check(w.entities.is_empty(),"entity lifetime "+id)
    simulation.sort()
    visual.sort()
    plain_times.sort()
    return {"contacts":outcomes,"hp":[w.actors[0].hp,w.actors[1].hp],"lifecycle":w.lifecycle,"starts":w.starts,"max_entities":max_entities,"max_travel":max_travel,"min_gap":min_gap,"sim_p95_us":simulation[int(simulation.size()*.95)],"view_p95_us":visual[int(visual.size()*.95)] if not visual.is_empty() else -1,"base_view_p95_us":plain_times[int(plain_times.size()*.95)] if not plain_times.is_empty() else -1}

func has_result(result:Dictionary,kind:String)->bool:
    for ev in result.contacts:
        if ev.result==kind:return true
    return false

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null:
        push_error("native raster and output path required")
        quit(2)
        return
    output=args[0]
    DirAccess.make_dir_recursive_absolute(output)
    for id in IDS:
        # Select a documented reachable gap from a fixed probe grid, never
        # move the target to manufacture contact inside the simulation.
        var probes:Array=[]
        var gap:float=-1.
        for d in [26.,32.,40.,48.,60.,80.]:
            var p:Dictionary=trace(id,d,"hit")
            probes.append({"gap":d,"result":p})
            if gap<0. and has_result(p,"hit"):gap=d
        check(gap>0.,"real reachable hit "+id)
        if gap<0.:gap=26.
        var hit:Dictionary=trace(id,gap,"hit",false,id+"_hit",true)
        var miss:Dictionary=trace(id,180.,"miss",false,id+"_miss",true)
        var block:Dictionary=trace(id,gap,"block",false,"",true)
        var mirrored:Dictionary=trace(id,gap,"hit",true,"",true)
        var moving:Dictionary=trace(id,gap+6.,"moving",false,"",true)
        var both:Dictionary=trace(id,gap,"both",false,"",true)
        check(has_result(hit,"hit") and hit.hp[1]<100 and hit.contacts.size()==1,"one hit "+id)
        check(has_result(miss,"miss") and miss.hp==[100,100],"real miss "+id)
        check(has_result(block,"block") and block.hp==[100,100],"block "+id)
        check(mirrored.hp==[hit.hp[1],hit.hp[0]],"mirror "+id)
        check(both.max_entities>=2,"concurrent "+id)
        check(not moving.contacts.is_empty(),"moving target resolved "+id)
        if id=="impact_dash":
            var distance:float=0.
            for row in hit.lifecycle:
                if row[2]=="contact":distance=float(row[4])
            check(distance>0. and distance<=15.001,"bounded dash")
        metrics[id]={"gap":gap,"probes":probes,"hit":hit,"miss":miss,"block":block,"mirror":mirrored,"moving":moving,"both":both}
    var interrupted:Dictionary=trace("energy_bolt",26.,"interrupt",false,"",true)
    var observed:bool=false
    for row in interrupted.lifecycle:
        if row[2]=="interrupt":observed=true
    check(observed and interrupted.contacts.is_empty(),"pre-release interruption")
    metrics.interrupt=interrupted
    # Abilities inactive: original world and extended world produce same
    # authoritative parent state, not just the same HP.
    var old=Baseline.new(26.)
    var new=W.new(26.)
    for t in TICKS:
        var a:Dictionary={"action":"jab"} if t==8 else {}
        var b:Dictionary={"action":"parry"} if t==26 else {}
        old.step(a,b)
        new.step(a,b)
        check(old.save()==bytes_to_var(new.save())[1],"005 unchanged")
    metrics.failures=failures
    var file:=FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(metrics))
    file.close()
    print("ABILITY_STUDY_001 ",JSON.stringify({"failures":failures,"scenarios":metrics.keys()}))
    quit(0 if failures.is_empty() else 1)
