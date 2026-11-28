extends SceneTree
const W=preload("res://lab/combat_study_003/world.gd")
const S=preload("res://lab/combat_study_003/skills.gd")
const View=preload("res://lab/combat_study_003/view.gd")
const TICKS:int=120
var view=View.new()
var failures:Array[String]=[]
var out:String
var metrics:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func scenario(name:String,gap:float,mode:int=2,mirror:bool=false,guard:bool=false,capture:bool=false)->Dictionary:
    var w=W.new(gap,true,mode)
    var inputs:Array=[]
    var states:Array=[]
    var logs:Array=[]
    var hud:Array=[]
    var min_y:float=0.
    var min_gap:float=gap
    var max_gap:float=gap
    var who:int=1 if mirror else 0
    for t in TICKS:
        var action:String=""
        match name:
            "pulse":action="pulse" if t==8 else ""
            "dash":action="dash" if t==8 else ("jab" if t==18 else "")
            "launch":action="launch" if t==8 else ""
            "route":action="jab" if t==8 else ("dash" if t==29 else ("pulse" if t==43 else ("launch" if t==56 else "")))
            "cancel_pulse":action="jab" if t==8 else ("pulse" if t==29 else "")
            "spam":action=S.ALL[int(t/3)%6] if t%3==0 else ""
        var a:Dictionary={"action":action}
        var b:Dictionary={"guard":guard}
        var pair:Array=[b,a] if mirror else [a,b]
        inputs.append(pair.duplicate(true))
        states.append(w.save())
        w.step(pair[0],pair[1])
        logs.append(w.events.duplicate(true))
        min_y=minf(min_y,float(w.actors[1-who].y))
        var g:float=w.root_x(1)-w.root_x(0)
        min_gap=minf(min_gap,g)
        max_gap=maxf(max_gap,g)
        check(g>=W.PUSH_GAP-.0001,"pushbox")
        for s in w.actors:check(float(s.y)<=.0001 and is_finite(float(s.x)),"finite ground offset")
        hud.append({"hp":[w.actors[0].hp,w.actors[1].hp],"action":w.actors[who].action,"remaining":w.actors[who].remaining,"stun":w.actors[1-who].stun,"gap":g,"height":-float(w.actors[1-who].y),"freeze":w.freeze,"events":w.events.duplicate(true)})
        if capture:
            var im:Image=view.render(w)
            check(im!=null,"native render")
            if im!=null:check(im.save_png(out.path_join("%s-%03d.png"%[name,t]))==OK,"save")
    var final:PackedByteArray=w.save()
    for at in [8,17,20,28,32,45,56,70,95]:
        w.restore(states[at])
        for t in range(at,TICKS):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==logs[t],"replay event "+name)
            if t+1<TICKS:check(w.save()==states[t+1],"replay state "+name)
        check(w.save()==final,"replay final "+name)
    var ids:Dictionary={}
    for ev in w.contacts:
        check(not ids.has(ev.id),"unique event")
        ids[ev.id]=true
    if capture:
        var f:=FileAccess.open(out.path_join("hud_"+name+".json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(hud))
        f.close()
    return {"starts":w.starts.duplicate(true),"contacts":w.contacts.duplicate(true),"links":w.links.duplicate(true),"hp":[w.actors[0].hp,w.actors[1].hp],"max_height":-min_y,"min_gap":min_gap,"max_gap":max_gap,"landings":w.landings.duplicate(true),"dash_ready":w.dash_ready.duplicate(true)}

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1 or view.raster==null:
        push_error("native raster required")
        quit(2)
        return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var pulse:Dictionary=scenario("pulse",42.,2,false,false,true)
    var dash:Dictionary=scenario("dash",38.,2,false,false,true)
    var launch:Dictionary=scenario("launch",26.,2,false,false,true)
    var route:Dictionary=scenario("route",26.,2,false,false,true)
    var blocked:Dictionary=scenario("launch",26.,2,false,true)
    var miss:Dictionary=scenario("pulse",80.)
    var mirror:Dictionary=scenario("pulse",42.,2,true)
    var pulse_block:Dictionary=scenario("pulse",42.,2,false,true)
    check(pulse.hp==[100,90] and pulse.max_gap>42.,"ranged pulse hit and push")
    check(miss.hp==[100,100] and miss.contacts.size()==1 and miss.contacts[0].result=="miss","finite pulse range")
    check(mirror.hp==[90,100],"pulse mirror")
    check(pulse_block.hp==[100,100] and pulse_block.max_gap<=42.001,"block no impulse")
    check(dash.dash_ready.size()==1 and dash.min_gap<30. and dash.links.size()==1 and dash.links[0].from=="dash","dash movement and cancel")
    check(launch.hp==[100,88] and launch.max_height>8. and launch.landings.size()==1,"launch hit and landing")
    check(blocked.hp==[100,100] and blocked.max_height==0. and blocked.landings.is_empty(),"blocked launch grounded")
    for mode in 3:
        var c:Dictionary=scenario("cancel_pulse",26.,mode)
        var spam:Dictionary=scenario("spam",26.,mode)
        check(c.links.is_empty() if mode==0 else (not c.links.is_empty() and c.links[0].to=="pulse"),"skill transition policy")
        metrics[str(mode)]={"cancel_pulse":c,"spam":spam}
    for mode in 3:
        check(not S.permits(mode,"jab","dash","miss",["jab"],8,21,20),"no whiff dash cancel")
        check(not S.permits(mode,"dash","jab","ready",["jab","dash"],8,11,10),"no reuse after dash")
    metrics.merge({"pulse":pulse,"dash":dash,"launch":launch,"route":route,"block":blocked,"miss":miss,"mirror":mirror,"pulse_block":pulse_block,"failures":failures})
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_003 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
