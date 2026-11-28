extends SceneTree
const W=preload("res://lab/combat_study_006/world.gd")
const C=preload("res://lab/combat_study_006/control.gd")
const Bot=preload("res://lab/combat_study_006/bot.gd")
const View=preload("res://lab/combat_study_005/view.gd")
const TICKS:int=240
var view=View.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func trace(name:String,mode:int=2,mirror:bool=false,capture:bool=false)->Dictionary:
    var w=W.new(26. if name not in ["spacing","counter"] else 38.,true,mode)
    var states:Array=[]
    var inputs:Array=[]
    var logs:Array=[]
    var hud:Array=[]
    var obs:Array=[]
    var min_gap:float=INF
    var max_gap:float=0.
    var count:Array=[0,0]
    var side:int=1 if mirror else 0
    for t in TICKS:
        var a:Dictionary={"edge":0}
        var b:Dictionary={"edge":0}
        match name:
            "retreat","stationary":
                if t==8:a.edge=C.LIGHT
                if name=="retreat" and t>=8 and t<30:b.back=true
                if t==30:b.edge=C.SKILL
            "locked":
                if t==8:a.edge=C.LIGHT
                if t>=29:b.back=true
            "guard_back":
                b.back=true
                b.guard=true
            "conflict":
                a.forward=true
                a.back=true
                if t==8:a.edge=C.LIGHT|C.HEAVY
            "hold":
                if t==8:a.edge=C.LIGHT
                a["held_attack"]=true
            "air":
                if t==8:a.edge=C.LIGHT;a.modifier=true
                if t==22:a.edge=C.MOBILITY
                if t==26:a.edge=C.LIGHT
                if t==35:a.edge=C.SKILL
                if t==44:a.edge=C.HEAVY
            "spacing","counter":
                obs.append(Bot.observe(w))
                var old:Dictionary=obs[maxi(0,obs.size()-7)]
                a=Bot.command(old,side,0,t)
                b=Bot.command(old,1-side,1 if name=="spacing" else 2,t)
        var pair:Array=[b,a] if mirror else [a,b]
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        var before:Array=[w.retreat_ticks[0],w.retreat_ticks[1]]
        var forbidden:Array=[]
        for i in 2:
            var s:Dictionary=w.actors[i]
            forbidden.append(w.freeze>0 or s.stun>0 or s.remaining>0 or s.interrupt or w.airborne(i) or bool(pair[i].get("guard",false)))
            if int(pair[i].get("edge",0))!=0 or not str(pair[i].get("action","")).is_empty():count[i]+=1
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        var g:float=w.root_x(1)-w.root_x(0)
        min_gap=minf(min_gap,g)
        max_gap=maxf(max_gap,g)
        check(g>=W.PUSH_GAP-.0001 and is_finite(g),"finite pushbox")
        for i in 2:
            if forbidden[i]:check(w.retreat_ticks[i]==before[i],"no retreat while locked")
        hud.append({"hp":[w.actors[0].hp,w.actors[1].hp],"action":[w.actors[0].action,w.actors[1].action],"gap":g,"retreat":w.retreat_distance.duplicate(),"stun":[w.actors[0].stun,w.actors[1].stun],"freeze":w.freeze})
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%s-%03d.png"%[name,t]))==OK,"save")
    var final:PackedByteArray=w.save()
    var result:Dictionary={"starts":w.starts.duplicate(true),"contacts":w.contacts.duplicate(true),"hp":[w.actors[0].hp,w.actors[1].hp],"punishments":w.punishments.duplicate(true),"min_gap":min_gap,"max_gap":max_gap,"retreat_distance":w.retreat_distance.duplicate(),"retreat_ticks":w.retreat_ticks.duplicate(),"commands":count,"air_hits":w.air_hits.duplicate(true)}
    for at in [8,20,28,35,44,70,110,180,220]:
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
    for m in [false,true]:
        check(C.decode({"edge":C.LIGHT,"modifier":m},false,false).action==("launch" if m else "jab"),"light map")
        check(C.decode({"edge":C.HEAVY,"modifier":m},false,false).action==("kick" if m else "cross"),"heavy map")
        check(C.decode({"edge":C.SKILL,"modifier":m},false,false).action==("dash" if m else "pulse"),"skill map")
    check(C.decode({"edge":C.DEFENSE},true,true).escape,"air defense edge")
    check(C.decode({"edge":C.DEFENSE},false,false).action=="parry","ground defense edge")
    check(not C.decode({"edge":C.LIGHT|C.SKILL},false,false).has("action"),"ambiguous edges")
    var still:Dictionary=trace("stationary",2,false,true)
    var retreat:Dictionary=trace("retreat",2,false,true)
    var mirror:Dictionary=trace("retreat",2,true)
    var locked:Dictionary=trace("locked")
    var guard_back:Dictionary=trace("guard_back")
    var conflict:Dictionary=trace("conflict")
    var hold:Dictionary=trace("hold")
    var air:Dictionary=trace("air")
    check(still.contacts[0].result=="hit" and retreat.contacts[0].result=="miss","spacing avoids real contact")
    check(retreat.retreat_distance[1]>10. and retreat.max_gap>36.,"retreat displacement")
    check(mirror.hp==[retreat.hp[1],retreat.hp[0]] and absf(mirror.retreat_distance[0]-retreat.retreat_distance[1])<.0001,"retreat mirror")
    check(locked.contacts[0].result=="hit" and locked.retreat_ticks[1]>0 and locked.max_gap<=W.RETREAT_CAP+.001,"locked movement resumes bounded")
    check(guard_back.retreat_ticks==[0,0],"guard stationary")
    check(conflict.starts.is_empty() and conflict.min_gap==26. and conflict.max_gap==26.,"neutral conflict")
    check(hold.starts.size()==1,"held no duplicate edge")
    check(air.hp==[100,57] and air.air_hits.size()==3,"compact input air route unchanged")
    for mode in 3:
        var spacing:Dictionary=trace("spacing",mode,false,mode==2)
        var counter:Dictionary=trace("counter",mode,false,mode==2)
        var mirrored:Dictionary=trace("spacing",mode,true)
        check(spacing.commands[0]>0 and spacing.commands[1]>0 and not spacing.contacts.is_empty(),"active commands")
        check(counter.commands[0]>0 and counter.commands[1]>0 and not counter.contacts.is_empty(),"counter commands")
        check(spacing.hp==[mirrored.hp[1],mirrored.hp[0]],"active mirror")
        metrics[str(mode)]={"spacing":spacing,"counter":counter,"mirror":mirrored}
    metrics.merge({"stationary":still,"retreat":retreat,"mirror":mirror,"locked":locked,"guard_back":guard_back,"conflict":conflict,"hold":hold,"air":air,"failures":failures})
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_006 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
