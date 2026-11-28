extends SceneTree
const W=preload("res://lab/combat_study_009/world.gd")
const Old=preload("res://lab/combat_study_008/world.gd")
const View=preload("res://lab/combat_study_009/view.gd")
const Bot=preload("res://lab/combat_study_009/bot.gd")
const OldBot=preload("res://lab/combat_study_006/bot.gd")
var view=View.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func trace(name:String,gap:float,n:int,enabled:bool=true,capture:bool=false,mirror:bool=false,style:int=1)->Dictionary:
    var w=W.new(gap,true,2,enabled)
    var baseline=Old.new(gap,true,2,2)
    var history:Array=[]
    var inputs:Array=[]
    var events:Array=[]
    var hud:Array=[]
    var obs:Array=[]
    var types:Dictionary={}
    var counts:Dictionary={}
    var seen:Dictionary={}
    var total:float=0.
    var initial:float=w.root_x(1 if mirror else 0)
    var first_ko:int=-1
    for t in n:
        var a:Dictionary={}
        var b:Dictionary={}
        if name.begins_with("duel"):
            obs.append(Bot.observe(w))
            var o:Dictionary=obs[maxi(0,obs.size()-7)]
            if w.actors[0].hp>0 and w.actors[1].hp>0:
                a=Bot.command(o,1 if mirror else 0,0,t) if enabled else OldBot.command(o,1 if mirror else 0,0,t)
                b=Bot.command(o,0 if mirror else 1,style,t) if enabled else OldBot.command(o,0 if mirror else 1,style,t)
        elif name=="mix":
            if t==8:a.action="energy_bolt"
            if t==40:b.action="impact_dash"
            if t==75:a.action="energy_blade"
            if t==115:b.action="jab"
            if t==150:a.action="launch"
        elif name=="interrupt":
            if t==8:b.action="jab"
            if t==24:a.action="energy_bolt"
        elif name=="old":
            if t==8:a.action="jab"
            if t==26:b.action="parry"
            if t==33:b.action="cross"
        else:
            var id:String=name.split(":")[0]
            var case:String=name.split(":")[1]
            if t==8:a.action=id
            if case=="block":b.guard=true
            if case=="both" and t==8:b.action=id
            if case=="moving":b.forward=true
        var pair:Array=[b,a] if mirror else [a,b]
        history.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        if not enabled or name=="old":
            baseline.step(pair[0],pair[1])
            check(bytes_to_var(w.save())[1]==baseline.save() and w.events==baseline.events,"008 exact parity "+name)
        check(w.root_x(1)-w.root_x(0)>=W.PUSH_GAP-.0001,"pushbox")
        total=maxf(total,absf(w.root_x(1 if mirror else 0)-initial))
        for e in w.events:
            check(not seen.has(e.id),"unique event ID")
            seen[e.id]=true
            counts[e.result]=int(counts.get(e.result,0))+1
            if e.result=="hit":types[e.attack]=int(types.get(e.attack,0))+1
        check(w.samples.size()==w.events.size(),"one trace per event")
        for s in w.samples:
            if s.kind=="strike":
                check(absf(Vector2(s.nearest).length()-float(s.distance))<.0002,"trace actual geometry "+name)
                if s.result in ["hit","block","parry","evade"]:check(s.distance<=s.radius+.0001,"contact radius")
        events.append(w.events.duplicate(true))
        if first_ko<0 and (w.actors[0].hp<=0 or w.actors[1].hp<=0):first_ko=t
        if capture:
            var snap:PackedByteArray=w.save()
            var im:Image=view.render(w)
            var label:String=name.replace(":","_")
            check(im.save_png(out.path_join("%s-%04d.png"%[label,t]))==OK,"png")
            hud.append(view.hud(w))
            check(snap==w.save(),"view read only")
    var final:PackedByteArray=w.save()
    for at in [8,16,28,int(n*.5),n-10]:
        w.restore(history[at])
        for t in range(at,n):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==events[t],"replay events "+name)
            if t+1<n:check(w.save()==history[t+1],"replay state "+name)
        check(w.save()==final,"replay final "+name)
    for row in w.full_dash_travel:check(row[2]<=15.0001 and row[2]>=0.,"full dash budget")
    if capture:
        var f:=FileAccess.open(out.path_join("hud_"+name.replace(":","_")+".json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(hud))
        f.close()
    return {"hp":[w.actors[0].hp,w.actors[1].hp],"counts":counts,"types":types,"contacts":w.contacts.map(func(e):return [e.tick,e.attack,e.result,e.attacker]),"starts":w.starts,"lifecycle":w.lifecycle,"dash":w.full_dash_travel,"max_root_delta":total,"ko":first_ko,"entities_left":w.entities.size()}

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    metrics.old=trace("old",26.,120)
    for id in ["energy_bolt","energy_blade","impact_dash"]:
        var gap:float=32. if id=="impact_dash" else 26.
        var hit:Dictionary=trace(id+":hit",gap,120,true,true)
        var miss:Dictionary=trace(id+":miss",180.,120)
        var block:Dictionary=trace(id+":block",gap,120)
        var both:Dictionary=trace(id+":both",gap,120)
        var mirror:Dictionary=trace(id+":hit",gap,120,true,false,true)
        check(hit.counts.get("hit",0)==1 and hit.hp[1]<100,"hit "+id)
        check(miss.hp==[100,100] and miss.counts.get("miss",0)==1,"miss "+id)
        check(block.hp==[100,100] and block.counts.get("block",0)==1,"block "+id)
        check(mirror.hp==[hit.hp[1],hit.hp[0]],"mirror "+id)
        check(hit.entities_left==0 and miss.entities_left==0,"lifetime "+id)
        if id=="impact_dash":
            check(hit.dash.size()==1 and miss.dash.size()==1,"completed dash")
        metrics[id]={"hit":hit,"miss":miss,"block":block,"both":both}
    metrics.interrupt=trace("interrupt",26.,120)
    check(metrics.interrupt.counts.get("hit",0)==1 and not metrics.interrupt.types.has("energy_bolt"),"pre-release interruption")
    metrics.mix=trace("mix",38.,240,true,true)
    metrics.duel_base=trace("duel_base",48.,360,false,true)
    metrics.duel_arsenal=trace("duel_arsenal",48.,360,true,true)
    metrics.duel_counter=trace("duel_counter",48.,360,true,true,false,2)
    var m:Dictionary=trace("duel_arsenal",48.,360,true,false,true)
    check(m.hp==[metrics.duel_arsenal.hp[1],metrics.duel_arsenal.hp[0]],"duel mirror")
    check(metrics.duel_arsenal.starts.size()>0 and metrics.duel_arsenal.contacts.size()>0,"active arsenal")
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_009 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
