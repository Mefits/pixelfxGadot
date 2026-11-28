extends SceneTree
const W=preload("res://lab/combat_study_005/world.gd")
const Bot=preload("res://lab/combat_study_005/bot.gd")
const Old=preload("res://lab/combat_study_004/world.gd")
const View=preload("res://lab/combat_study_005/view.gd")
const TICKS:int=180
var view=View.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func run_trace(name:String,gap:float=26.,profile:int=2,mirror:bool=false,capture:bool=false)->Dictionary:
    var w=W.new(gap,true,profile)
    var states:Array=[]
    var logs:Array=[]
    var inputs:Array=[]
    var hud:Array=[]
    var observations:Array=[]
    var commands:Array=[0,0]
    var max_locked:Array=[0,0]
    var current_locked:Array=[0,0]
    for t in TICKS:
        var a:Dictionary={}
        var b:Dictionary={}
        match name:
            "parry","early","late","block":
                if t==8:a.action="jab"
                if name=="parry" and t==26:b.action="parry"
                if name=="early" and t==20:b.action="parry"
                if name=="late" and t==29:b.action="parry"
                if name=="block":b.guard=true
                if name=="parry" and t==33:b.action="cross"
                if name=="early" and t==28:b.action="cross"
            "whiff":
                if t==8:a.action="jab"
                if t==22:b.action="pulse"
            "air_escape","air_control","escape_early":
                var action:String="launch" if t==8 else ("chase" if t==22 else ("air_cross" if t==26 else ("air_pulse" if t==35 else ("slam" if t==44 else ""))))
                a.action=action
                if name=="air_escape" and t in [33,35,36,37,40,44,50]:b.escape=true
                if name=="escape_early" and t==8:b.escape=true
            "active":
                observations.append(Bot.observe(w))
                var obs:Dictionary=observations[maxi(0,observations.size()-7)]
                a=Bot.command(obs,1 if mirror else 0,0,t)
                b=Bot.command(obs,0 if mirror else 1,1,t)
        var pair:Array=[b,a] if mirror else [a,b]
        for i in 2:
            if not str(pair[i].get("action","")).is_empty():commands[i]+=1
            if w.freeze==0:
                var s:Dictionary=w.actors[i]
                if s.stun>0 or s.remaining>0 or w.airborne(i):
                    current_locked[i]+=1
                    max_locked[i]=maxi(max_locked[i],current_locked[i])
                else:current_locked[i]=0
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        check(w.root_x(1)-w.root_x(0)>=W.PUSH_GAP-.0001,"pushbox")
        for s in w.actors:
            check(float(s.y)<=.0001 and is_finite(float(s.x)),"finite floor")
        hud.append({"hp":[w.actors[0].hp,w.actors[1].hp],"action":[w.actors[0].action,w.actors[1].action],"stun":[w.actors[0].stun,w.actors[1].stun],"escape":[not w.actors[0].escape_used,not w.actors[1].escape_used],"parries":w.parries.size(),"escapes":w.escapes.size(),"punish":w.punishments.size(),"freeze":w.freeze})
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%s-%03d.png"%[name,t]))==OK,"save")
    var final:PackedByteArray=w.save()
    var result:Dictionary={"starts":w.starts.duplicate(true),"contacts":w.contacts.duplicate(true),"links":w.links.duplicate(true),"hp":[w.actors[0].hp,w.actors[1].hp],"parries":w.parries.duplicate(true),"escapes":w.escapes.duplicate(true),"evades":w.evades.duplicate(true),"punishments":w.punishments.duplicate(true),"landings":w.landings.duplicate(true),"commands":commands,"max_locked":max_locked,"air_hits":w.air_hits.duplicate(true)}
    for at in [8,17,22,26,28,33,35,44,60,100,140]:
        w.restore(states[at])
        for t in range(at,TICKS):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==logs[t],"replay event "+name)
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
    var p:Dictionary=run_trace("parry",26.,2,false,true)
    var early:Dictionary=run_trace("early")
    var late:Dictionary=run_trace("late")
    var block:Dictionary=run_trace("block")
    var whiff:Dictionary=run_trace("whiff",42.,2,false,true)
    var control:Dictionary=run_trace("air_control",26.,2,false,true)
    var escaped:Dictionary=run_trace("air_escape",26.,2,false,true)
    var escape_early:Dictionary=run_trace("escape_early")
    var active:Dictionary=run_trace("active",34.,2,false,true)
    var mirror:Dictionary=run_trace("parry",26.,2,true)
    check(p.parries.size()==1 and p.hp[1]==100,"timed parry no damage")
    check(p.hp[0]<100,"parry counter hit")
    check(early.parries.is_empty() and early.hp[1]<100,"early parry vulnerable")
    check(late.parries.is_empty() and late.hp[1]<100,"late parry fails")
    check(block.hp==[100,100] and block.parries.is_empty(),"ordinary guard")
    check(whiff.contacts.size()>=2 and whiff.contacts[0].result=="miss" and whiff.hp[0]<100 and not whiff.punishments.is_empty(),"actual whiff punish")
    check(control.hp==[100,57] and control.air_hits.size()==3,"004 air control exact")
    check(escaped.escapes.size()==1 and escaped.hp[1]>control.hp[1] and escaped.air_hits.size()<control.air_hits.size(),"limited air escape changes route")
    check(escape_early.escapes.is_empty() and escape_early.hp==control.hp,"no escape before hit")
    check(mirror.hp==[p.hp[1],p.hp[0]] and mirror.parries.size()==1,"mirror defense")
    check(active.commands[0]>0 and active.commands[1]>0 and active.contacts.size()>0,"active opponent input and contact")
    for mode in 3:
        metrics[str(mode)]={"active":run_trace("active",34.,mode),"active_mirror":run_trace("active",34.,mode,true),"air_escape":run_trace("air_escape",26.,mode)}
    metrics.merge({"parry":p,"early":early,"late":late,"block":block,"whiff":whiff,"air_control":control,"air_escape":escaped,"escape_early":escape_early,"active":active,"mirror":mirror,"failures":failures})
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_005 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
