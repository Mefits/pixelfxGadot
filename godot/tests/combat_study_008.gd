extends SceneTree
const W=preload("res://lab/combat_study_008/world.gd")
const Old=preload("res://lab/combat_study_007/world.gd")
const V=preload("res://lab/combat_study_008/view.gd")
const Bot=preload("res://lab/combat_study_006/bot.gd")
var view=V.new()
var out:String
var failures:Array[String]=[]
var metrics:Dictionary={}

func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)

func trace(name:String,variant:int,length:int,gap:float=26.,capture:bool=false,mirror:bool=false,opponent:int=2)->Dictionary:
    var w=W.new(gap,true,2,variant)
    var old:RefCounted=null
    if variant==0:old=Old.new(gap,true,2,false)
    var disabled=W.new(gap,true,2,variant,false)
    var frames:Array=[]
    var states:Array=[]
    var inputs:Array=[]
    var events:Array=[]
    var obs:Array=[]
    var counts:Dictionary={}
    var commands:Array=[0,0]
    var neutral:Array=[0,0]
    var stun_run:Array=[0,0]
    var max_stun:Array=[0,0]
    var moving:Array=[0.,0.]
    var ko:int=-1
    var first_close:int=-1
    var first_free:int=-1
    var min_gap:float=INF
    var max_gap:float=0.
    for t in length:
        var a:Dictionary={}
        var b:Dictionary={}
        match name:
            "recovery":
                if t==8:a.action="jab"
                if t>=29 and t<52:a.back=true
            "approach":
                a.forward=t<45
                b.forward=t<45
                if t==46:a.action="jab"
            "parry":
                if t==8:a.action="jab"
                if t==26:b.action="parry"
                if t==33:b.action="cross"
            "air":
                if t==8:a.action="launch"
                if t==22:a.action="chase"
                if t==26:a.action="air_cross"
                if t==35:a.action="air_pulse"
                if t==44:a.action="slam"
            "guard":
                if t==8:a.action="jab"
                b.guard=true
            _:
                obs.append(Bot.observe(w))
                if w.actors[0].hp>0 and w.actors[1].hp>0:
                    var o:Dictionary=obs[maxi(0,obs.size()-7)]
                    a=Bot.command(o,1 if mirror else 0,0,t)
                    b=Bot.command(o,0 if mirror else 1,opponent,t)
        var pair:Array=[b,a] if mirror else [a,b]
        var before:Array=[w.root_x(0),w.root_x(1)]
        for i in 2:
            if not str(pair[i].get("action","")).is_empty():commands[i]+=1
            if w.freeze==0 and w.actors[0].hp>0 and w.actors[1].hp>0:
                var s:Dictionary=w.actors[i]
                if s.stun>0:
                    stun_run[i]+=1
                    max_stun[i]=maxi(max_stun[i],stun_run[i])
                else:stun_run[i]=0
                if s.stun==0 and s.remaining==0 and not s.interrupt and not w.airborne(i):neutral[i]+=1
        states.append(w.save())
        inputs.append(pair.duplicate(true))
        w.step(pair[0],pair[1])
        disabled.step(pair[0],pair[1])
        var state:PackedByteArray=w.save()
        check(state==disabled.save() and w.events==disabled.events,"diagnostic parity "+name)
        if old!=null:
            old.step(pair[0],pair[1])
            check(bytes_to_var(state)[2]==old.save() and w.events==old.events,"A exact baseline "+name)
        for i in 2:moving[i]+=absf(w.root_x(i)-float(before[i]))
        for s in w.samples:
            var key:String=s.result
            counts[key]=int(counts.get(key,0))+1
            if s.kind=="strike" and s.result in ["hit","block","parry","evade"]:check(s.distance<=s.radius+.0001 and s.front,"real contact")
        events.append(w.events.duplicate(true))
        var data:Dictionary=view.hud(w)
        frames.append(data)
        var g:float=data.gap
        min_gap=minf(g,min_gap)
        max_gap=maxf(g,max_gap)
        if first_close<0 and g<=26.01:first_close=t
        if name=="recovery" and first_free<0 and w.retreat_ticks[0]>0:first_free=t
        if ko<0 and (w.actors[0].hp<=0 or w.actors[1].hp<=0):ko=t
        check(is_finite(g) and g>=W.PUSH_GAP-.0001,"pushbox")
        if capture:
            var im:Image=view.render(w)
            check(im.save_png(out.path_join("%s_%d-%04d.png"%[name,variant,t]))==OK,"capture")
        check(w.save()==state,"read only")
    var final:PackedByteArray=w.save()
    for at in [8,28,44,int(length*.5),length-10]:
        w.restore(states[at])
        for t in range(at,length):
            w.step(inputs[t][0],inputs[t][1])
            check(w.events==events[t],"replay event "+name)
            if t+1<length:check(w.save()==states[t+1],"replay state "+name)
        check(w.save()==final,"replay final "+name)
    if capture:
        var f:=FileAccess.open(out.path_join("hud_%s_%d.json"%[name,variant]),FileAccess.WRITE)
        f.store_string(JSON.stringify(frames))
        f.close()
    return {"hp":[w.actors[0].hp,w.actors[1].hp],"counts":counts,"starts":w.starts.size(),"commands":commands,"contact_ticks":w.contacts.map(func(e):return [e.tick,e.attack,e.result]),"neutral_ticks":neutral,"max_stun":max_stun,"distance_travelled":moving,"retreat":w.retreat_distance.duplicate(),"min_gap":min_gap,"max_gap":max_gap,"first_close":first_close,"first_free":first_free,"ko":ko,"freeze":w.frozen_ticks}

func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    out=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var base=W.new(26.,true,2,0)
    for variant in 3:
        var w=W.new(26.,true,2,variant)
        var timing:Dictionary={}
        for id in base.bank:
            var a:Dictionary=base.bank[id]
            var b:Dictionary=w.bank[id]
            check(a.markers==b.markers,"marker unchanged "+id)
            check(base.rule_for(id)==w.rule_for(id),"rule unchanged "+id)
            if variant>0 and id in W.GROUND_STRIKES:
                var m:int=int(a.markers.keys()[0])
                check(b.frames.size()<a.frames.size(),"shorter recovery "+id)
                for i in range(m+1):
                    for k in ["frames","roots","feet"]:check(a[k][i]==b[k][i],"startup unchanged "+id)
            else:check(a==b,"unchanged clip "+id)
            timing[id]=[a.frames.size(),b.frames.size()]
        var d:Dictionary={"timing":timing}
        d.recovery=trace("recovery",variant,120,45.,true)
        d.approach=trace("approach",variant,120,80.,true)
        d.parry=trace("parry",variant,120)
        d.air=trace("air",variant,120)
        d.guard=trace("guard",variant,120)
        d.duel=trace("duel",variant,360,38.,true,false,2)
        var mirror:Dictionary=trace("duel",variant,360,38.,false,true,2)
        d.spacing_duel=trace("spacing_duel",variant,360,38.,false,false,1)
        check(d.duel.hp==[mirror.hp[1],mirror.hp[0]],"mirror")
        check(d.recovery.hp==[100,100] and d.recovery.counts.get("miss",0)==1,"real whiff")
        check(d.parry.hp==[86,100] and d.parry.counts.get("parry",0)==1,"parry retained")
        check(d.air.hp==[100,57],"air retained")
        check(d.guard.hp==[100,100] and d.guard.counts.get("block",0)==1,"block retained")
        metrics[str(variant)]=d
    check(metrics["1"].recovery.first_free<metrics["0"].recovery.first_free,"earlier control after whiff")
    check(metrics["2"].approach.first_close>=0 and metrics["2"].approach.first_close<metrics["1"].approach.first_close,"faster approach")
    check(metrics["2"].recovery.retreat[0]>metrics["1"].recovery.retreat[0],"faster retreat")
    metrics.failures=failures
    var f:=FileAccess.open(out.path_join("metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(metrics))
    f.close()
    print("COMBAT_STUDY_008 ",JSON.stringify(metrics))
    quit(0 if failures.is_empty() else 1)
