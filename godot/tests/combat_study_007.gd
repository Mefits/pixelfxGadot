extends SceneTree
const W=preload("res://lab/combat_study_007/world.gd")
const Old=preload("res://lab/combat_study_006/world.gd")
const View=preload("res://lab/combat_study_007/view.gd")
const Bot=preload("res://lab/combat_study_006/bot.gd")
var view=View.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}

func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func trace(name:String,gap:float,length:int,style_a:int=0,style_b:int=1,capture:bool=true,mirror:bool=false)->Dictionary:
    var w=W.new(gap,true,2)
    var old=Old.new(gap,true,2)
    var disabled=W.new(gap,true,2,false)
    var frames:Array=[]
    var inputs:Array=[]
    var states:Array=[]
    var events:Array=[]
    var observations:Array=[]
    var counts:Dictionary={}
    var starts_before:int=0
    var neutral:Array=[0,0]
    var locked:Array=[0,0]
    var lock_run:Array=[0,0]
    var damage_lock:Array=[0,0]
    var damage_run:Array=[0,0]
    var commands:Array=[0,0]
    var ko_tick:int=-1
    var min_gap:float=INF
    var max_gap:float=0.
    var last_hp:Array=[100,100]
    for t in length:
        var a:Dictionary={}
        var b:Dictionary={}
        match name:
            "neutral":
                a.forward=t<20
                b.forward=t<20
                if t==21:a.action="jab";b.action="jab"
            "spacing":
                if t==8:a.action="jab"
                if t>=8 and t<30:b.back=true
                if t==30:b.action="pulse"
            "air":
                if t==8:a.action="launch"
                if t==22:a.action="chase"
                if t==26:a.action="air_cross"
                if t==35:a.action="air_pulse"
                if t==44:a.action="slam"
            "pressure":
                if t==8:a.action="jab"
                if t==32:a.action="cross"
                if t==60:a.action="kick"
                b.guard=t<85
            "counter":
                if t==8:a.action="jab"
                if t==26:b.action="parry"
                if t==33:b.action="cross"
            "dash":
                if t==8:a.action="dash"
                if t==18:a.action="jab"
            _:
                observations.append(Bot.observe(w))
                var obs:Dictionary=observations[maxi(0,observations.size()-7)]
                a=Bot.command(obs,1 if mirror else 0,style_a,t)
                b=Bot.command(obs,0 if mirror else 1,style_b,t)
        var pair:Array=[b,a] if mirror else [a,b]
        for i in 2:
            if not str(pair[i].get("action","")).is_empty():commands[i]+=1
            if w.freeze==0 and w.actors[0].hp>0 and w.actors[1].hp>0:
                var s:Dictionary=w.actors[i]
                if s.stun>0 or s.remaining>0 or s.interrupt or w.airborne(i):
                    lock_run[i]+=1
                    locked[i]=maxi(locked[i],lock_run[i])
                else:lock_run[i]=0;neutral[i]+=1
                if s.stun>0:
                    damage_run[i]+=1
                    damage_lock[i]=maxi(damage_lock[i],damage_run[i])
                else:damage_run[i]=0
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        old.step(pair[0],pair[1])
        disabled.step(pair[0],pair[1])
        var state:PackedByteArray=w.save()
        check(state==old.save() and state==disabled.save(),"baseline/disabled snapshot "+name)
        check(w.events==old.events and w.events==disabled.events,"baseline event "+name)
        check(disabled.samples.is_empty(),"disabled trace")
        check(w.samples.size()==w.events.size(),"one sample per event")
        for i in w.samples.size():
            var s:Dictionary=w.samples[i]
            var e:Dictionary=w.events[i]
            check(s.id==e.id and s.result==e.result and s.tick==e.tick,"trace identity")
            if s.kind=="strike":
                check(absf(Vector2(s.nearest).length()-float(s.distance))<.0001,"actual distance "+name)
                if s.result in ["hit","block","parry","evade"]:check(float(s.distance)<=float(s.radius)+.0001 and s.front,"contact geometry")
            var key:String=str(s.result)
            counts[key]=int(counts.get(key,0))+1
        events.append(w.events.duplicate(true))
        var data:Dictionary=view.hud(w)
        frames.append(data)
        var g:float=data.gap
        min_gap=minf(g,min_gap)
        max_gap=maxf(g,max_gap)
        check(is_finite(g) and g>=W.PUSH_GAP-.0001,"pushbox")
        if ko_tick<0 and (w.actors[0].hp<=0 or w.actors[1].hp<=0):ko_tick=t
        if capture:
            var im:Image=view.render(w)
            check(im.save_png(out.path_join("%s-%04d.png"%[name,t]))==OK,"Godot capture")
        check(w.save()==state,"view read only")
    var final:PackedByteArray=w.save()
    var result:Dictionary={"hp":[w.actors[0].hp,w.actors[1].hp],"counts":counts,"starts":w.starts.duplicate(true),"contacts":w.contacts.duplicate(true),"commands":commands,"min_gap":min_gap,"max_gap":max_gap,"neutral_ticks":neutral,"max_action_lock":locked,"max_stun":damage_lock,"ko_tick":ko_tick,"freeze_ticks":w.frozen_ticks,"retreat":w.retreat_distance.duplicate(),"air_hits":w.air_hits.size(),"snapshot_bytes":final.size()}
    for at in [8,28,44,75,length/2,length-10]:
        var i0:int=int(at)
        if i0>=length:continue
        w.restore(states[i0])
        for t in range(i0,length):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==events[t],"restore event "+name)
            if t+1<length:check(w.save()==states[t+1],"restore state "+name)
        check(w.save()==final,"restore final "+name)
    if capture:
        var f:=FileAccess.open(out.path_join("hud_"+name+".json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(frames))
        f.close()
    return result

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    metrics.neutral=trace("neutral",38.,120)
    metrics.spacing=trace("spacing",26.,120)
    metrics.air=trace("air",26.,120)
    metrics.pressure=trace("pressure",26.,120)
    metrics.counter=trace("counter",26.,120)
    metrics.dash=trace("dash",38.,120)
    check(metrics.neutral.hp==[92,92],"neutral trade")
    check(metrics.spacing.hp==[90,100] and metrics.spacing.counts.get("miss",0)>0,"spacing")
    check(metrics.air.hp==[100,57] and metrics.air.air_hits==3,"air route")
    check(metrics.pressure.hp==[100,100] and metrics.pressure.counts.get("block",0)>0,"pressure")
    check(metrics.counter.hp==[86,100] and metrics.counter.counts.get("parry",0)==1,"counter")
    check(metrics.dash.hp==[100,92],"dash")
    for pair in [[0,1],[0,2],[1,2]]:
        var name:String="duel_%d%d"%[pair[0],pair[1]]
        var a:Dictionary=trace(name,38.,480,pair[0],pair[1])
        var b:Dictionary=trace(name,38.,480,pair[0],pair[1],false,true)
        check(a.hp==[b.hp[1],b.hp[0]],"duel mirror "+name)
        check(a.commands[0]>0 and a.commands[1]>0 and a.contacts.size()>0,"active duel "+name)
        metrics[name]=a
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    # Keep full trace in JSON artifact, compact report in log.
    var report:Dictionary={}
    for k in metrics:
        if k=="failures":continue
        var s:Dictionary=metrics[k].duplicate(true)
        s.erase("starts")
        s.erase("contacts")
        report[k]=s
    report.failures=failures
    print("COMBAT_STUDY_007 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
