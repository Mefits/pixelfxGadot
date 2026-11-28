extends SceneTree
const W=preload("res://lab/combat_study_001/world.gd")
const View=preload("res://lab/combat_study_001/view.gd")
var failures:Array[String]=[]
var out:String
var view=View.new()
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func single(gap:float,move:String,mirror:bool=false,guard:bool=false,trade:bool=false,stop:bool=true,capture:bool=false)->Dictionary:
    var w=W.new(gap,stop)
    var logs:Array=[]
    var states:Array=[]
    var inputs:Array=[]
    for t in 72:
        var a:Dictionary={"action":move if t==8 else ""}
        var b:Dictionary={"action":move if t==8 and trade else "","guard":guard}
        var pair:Array=[b,a] if mirror else [a,b]
        inputs.append(pair.duplicate(true))
        states.append(w.save())
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%s-%03d.png"%[("block" if guard else ("miss" if gap>65 else ("trade" if trade else "hit"))),t]))==OK,"save")
    var final:PackedByteArray=w.save()
    for at in [0,8,28,31,40,55]:
        w.restore(states[at])
        for t in range(at,72):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==logs[t],"same-process replay events")
        check(w.save()==final,"same-process replay state")
    var flat:Array=[]
    for l in logs:flat.append_array(l)
    return {"events":flat,"hp":[w.actors[0].hp,w.actors[1].hp],"frozen_ticks":w.frozen_ticks,"starts":w.starts.duplicate(true),"gap":gap}

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null:
        push_error("native raster and output required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    # One fixed contact distance selected by actual native marker sweep;
    # not adjusted per tick or per opponent. Report each candidate range.
    var found:Dictionary={}
    for move in W.RULES:
        var hits:Array=[]
        for gap in [18.,22.,26.,30.,34.,38.,42.]:
            var r:Dictionary=single(gap,move)
            if r.events.size()==1 and r.events[0].result=="hit":hits.append(gap)
        metrics[move+"_hit_gaps"]=hits
        check(not hits.is_empty(),"reachable "+move)
        if not hits.is_empty():found[move]=hits[hits.size()/2]
    if not found.has("jab"):
        quit(1)
        return
    var g:float=found.jab
    var h:Dictionary=single(g,"jab",false,false,false,true,true)
    var m:Dictionary=single(80.,"jab",false,false,false,true,true)
    var b:Dictionary=single(g,"jab",false,true,false,true,true)
    var tr:Dictionary=single(g,"jab",false,false,true,true,true)
    var mir:Dictionary=single(g,"jab",true)
    var no:Dictionary=single(g,"jab",false,false,false,false)
    check(h.events.size()==1 and h.hp==[100,92],"hit once")
    check(m.events.size()==1 and m.events[0].result=="miss" and m.hp==[100,100],"whiff")
    check(b.events.size()==1 and b.events[0].result=="block" and b.hp==[100,100],"block")
    check(tr.events.size()==2 and tr.hp==[92,92],"simultaneous trade")
    check(mir.hp==[92,100],"mirror")
    check(h.frozen_ticks==3 and no.frozen_ticks==0 and no.hp==h.hp,"hitstop separate from damage")
    var buffer=W.new(g)
    for t in 90:
        var action:String="jab" if t==0 else ("cross" if t==26 else "")
        buffer.step({"action":action},{})
    check(buffer.starts.size()==2 and buffer.starts[1][0]>=31,"buffer after full recovery")
    var spam=W.new(g)
    for t in 90:spam.step({"action":"jab" if t<10 else ""},{})
    check(spam.starts.size()==1,"expired early spam")
    metrics.merge({"hit":h,"miss":m,"block":b,"trade":tr,"mirror":mir,"no_hitstop":no,"buffer_starts":buffer.starts,"failures":failures})
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_001 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
