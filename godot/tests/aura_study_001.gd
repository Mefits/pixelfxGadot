extends SceneTree
const W=preload("res://lab/ability_study_001/world.gd")
const View=preload("res://lab/aura_study_001/view.gd")
const Trace=preload("res://lab/aura_study_001/trace.gd")
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func percentile(values:Array,f:float)->int:
    values.sort()
    return int(values[mini(values.size()-1,floori(values.size()*f))])
func run()->void:
    var args:=OS.get_cmdline_user_args()
    var view=View.new()
    if args.size()!=1 or view.raster==null:
        push_error("native raster/output required")
        quit(2)
        return
    var out:String=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var reference:Array=[]
    var names:Array=["control","cloak","tail","twin"]
    for mode in 4:
        var w=W.new(Trace.GAP)
        view.mode=mode
        view.reset()
        var sim:Array=[]
        var body:Array=[]
        var fx:Array=[]
        var max_move:float=0.
        var root0:float=w.root_x(0)
        var hashes:Array=[]
        var previous_hash:int=0
        var changed:int=0
        for t in Trace.TICKS:
            var c:Array=Trace.commands(t)
            var start:int=Time.get_ticks_usec()
            w.step(c[0],c[1])
            sim.append(Time.get_ticks_usec()-start)
            var before:PackedByteArray=w.save()
            if mode==0:reference.append(before)
            else:check(before==reference[t],"same authoritative state")
            max_move=maxf(max_move,absf(w.root_x(0)-root0))
            var im:Image=view.render(w)
            check(im!=null,"native render")
            check(w.save()==before,"visual state isolation")
            if im==null:continue
            body.append(view.body_us)
            fx.append(view.aura_us)
            var h:int=hash(im.get_data())
            if t>0 and h!=previous_hash:changed+=1
            previous_hash=h
            hashes.append(h)
            check(im.save_png(out.path_join("%s-%03d.png"%[names[mode],t]))==OK,"png")
        check(max_move>10.,"locomotion trace")
        check(changed>50,"animated capture")
        if mode>0:
            # Same reset/input sequence must reproduce actual visual frames.
            var replay=W.new(Trace.GAP)
            view.reset()
            for t in 45:
                var c:Array=Trace.commands(t)
                replay.step(c[0],c[1])
                var im:Image=view.render(replay)
                check(im!=null and hash(im.get_data())==hashes[t],"cosmetic replay from reset")
        metrics[names[mode]]={"sim_p95_us":percentile(sim,.95),"body_p95_us":percentile(body,.95),"aura_p95_us":percentile(fx,.95),"aura_max_us":percentile(fx,1.),"root_travel":max_move,"hp":[w.actors[0].hp,w.actors[1].hp],"contacts":w.contacts,"changed_frames":changed}
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("AURA_STUDY_001 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
