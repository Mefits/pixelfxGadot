extends SceneTree
const W=preload("res://lab/ability_study_001/world.gd")
const Old=preload("res://lab/aura_study_001/view.gd")
const View=preload("res://lab/aura_study_002/view.gd")
const Trace=preload("res://lab/aura_study_002/trace.gd")
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func percentile(values:Array,f:float)->int:
    if values.is_empty():return -1
    values.sort()
    return int(values[mini(values.size()-1,floori(values.size()*f))])
func run()->void:
    var args:=OS.get_cmdline_user_args()
    var old=Old.new()
    var view=View.new()
    if args.size()!=1 or view.raster==null or view.native_aura==null:
        push_error("native body/aura raster and output required")
        quit(2)
        return
    var out:String=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var reference:Array=[]
    var names:Array=["legacy_cloak","native_cloak","fist","palm"]
    for mode in 4:
        var w=W.new(Trace.GAP)
        var v=old if mode==0 else view
        v.mode=maxi(1,mode)
        v.reset()
        var sim:Array=[]
        var body:Array=[]
        var fx:Array=[]
        var total:Array=[]
        var hashes:Array=[]
        var max_extension:float=0.
        var active:int=0
        var peak_pixels:int=0
        var peak_tick:int=-1
        var overlap_hit:bool=false
        var last_growth:float=0.
        for t in Trace.TICKS:
            var c:Array=Trace.commands(t)
            var start:int=Time.get_ticks_usec()
            w.step(c[0],c[1])
            sim.append(Time.get_ticks_usec()-start)
            var before:PackedByteArray=w.save()
            if mode==0:reference.append(before)
            else:check(before==reference[t],"same authoritative snapshot")
            start=Time.get_ticks_usec()
            var im:Image=v.render(w)
            total.append(Time.get_ticks_usec()-start)
            check(im!=null,"native frame")
            check(w.save()==before,"render cannot change world")
            if im==null:continue
            body.append(v.body_us)
            fx.append(v.aura_us)
            hashes.append(hash(im.get_data()))
            if mode>=2:
                var g:float=view.hand_fx.growth
                if g>0.:
                    active+=1
                    peak_pixels=maxi(peak_pixels,view.active_pixels)
                if view.hand_fx.extension>max_extension:
                    max_extension=view.hand_fx.extension
                    peak_tick=t
                if w.actors[0].action not in ["cross","jab"]:check(g==0.,"no hand outside attack")
                if w.freeze>0 and t>0 and g>0. and last_growth>0.: # hit tick may enter freeze
                    check(absf(g-last_growth)<.7,"bounded growth across impact")
                for ev in w.events:
                    if ev.attacker==0 and ev.attack=="cross" and ev.result=="hit" and g>.8:overlap_hit=true
                last_growth=g
            check(im.save_png(out.path_join("%s-%03d.png"%[names[mode],t]))==OK,"png")
        if mode>=2:
            check(active>8 and peak_pixels>60 and max_extension>12.,"articulated hand actually grown")
            check(overlap_hit,"manifestation at real hit")
            check(view.floor_clean,"no aura under floor")
            check(view.hand_fx.growth==0.,"hand retracts")
        if mode>0:
            var replay=W.new(Trace.GAP)
            view.reset()
            for t in 80:
                var c:Array=Trace.commands(t)
                replay.step(c[0],c[1])
                var im:Image=view.render(replay)
                check(im!=null and hash(im.get_data())==hashes[t],"visual replay from reset")
        metrics[names[mode]]={"sim_p95_us":percentile(sim,.95),"body_p95_us":percentile(body,.95),"aura_p95_us":percentile(fx,.95),"render_p95_us":percentile(total,.95),"render_max_us":percentile(total,1.),"peak_extension":max_extension,"active_ticks":active,"peak_seed_pixels":peak_pixels,"peak_tick":peak_tick,"hit_at_peak":overlap_hit,"hp":[w.actors[0].hp,w.actors[1].hp],"contacts":w.contacts}
    # Mirror: the effect follows the other fighter's far hand rather than fixed screen direction.
    var mirrored=W.new(Trace.GAP)
    view.mode=3
    view.owner=1
    view.reset()
    var mirror_seen:bool=false
    for t in 80:
        var c:Array=Trace.commands(t)
        mirrored.step(c[1],c[0])
        var im:Image=view.render(mirrored)
        if im!=null and view.hand_fx.growth>.85:
            var wrist:Vector2=mirrored.tip(1,"hand_far")+Vector2(float(view.ORIGIN_X)/view.SCALE,float(view.FLOOR)/view.SCALE)
            if view.hand_fx.tip.x<wrist.x:mirror_seen=true
    check(mirror_seen,"mirrored hand direction")
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("AURA_STUDY_002 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
