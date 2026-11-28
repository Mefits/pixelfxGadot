extends SceneTree
const Session=preload("res://lab/spatial_lab/spatial_session.gd")
const History=preload("res://lab/spatial_lab/spatial_history.gd")
const Body=preload("res://lab/spatial_lab/spatial_body.gd")
const CFG={"width":480,"height":270,"origin":[240,219],"density":3,"ink":0xff000000,"outline":3,"light":[-.48,-.64,.6],"seams":false,"materials":[[0xffe6ded7,0xffbdb3a8,0xff9e9081,0xff746759],[0xffa09d74,0xff827d50,0xff656139,0xff4a4628],[0xff655a4c,0xff50473b,0xff3c342c,0xff29231e],[0xff7278e2,0xff4c53bb,0xff35398b,0xff27265c]]}
var failures:Array[String]=[]
var trace:Array=[]
var max_bytes:int=0
var restores:int=0
var corrections:int=0
var rendered:int=0
var depth_differences:int=0
var raster
var body
func _initialize()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func command(t:int,corrected:bool=true)->Dictionary:
    if t==0:return {"start":true,"tuning":{"leg":0}}
    if t==3:return {"tuning":{"leg":1 if corrected else 0,"prep_ticks":8,"strike_ticks":4}}
    if t==40:return {"start":true,"run_ticks":20}
    if t==45:return {"tuning":{"leg":0}}
    if t==85:return {"start":true}
    return {}
func render_probe(s)->void:
    if s.actor.player.current.is_empty():return
    var before:PackedByteArray=s.save()
    var cfg:Dictionary=CFG.duplicate(true)
    cfg.origin[0]-=s.actor.origin_x*3.
    var q:Dictionary=raster.render(cfg,body.make(s.actor.player.rig,s.actor.pose))
    check(q.get("ok",false),"native rendering")
    check(s.save()==before,"render cannot mutate state")
    rendered+=1
func sample(s)->Dictionary:
    var a=s.actor
    var pts:Array=[]
    if not a.player.current.is_empty():
        for id in a.player.rig.ids_in_order():
            var p:Vector3=a.player.rig.point3(id)
            pts.append([p.x,p.y,p.z])
    return {"tick":s.tick,"serial":s.serial,"age":a.age,"active":a.active,"fired":a.fired,"leg":a.striking,"yaw":a.player.rig.yaw_units,"planted":a.planted,"events":s.events.duplicate(true),"exact":s.exact_hash(),"grid":s.grid_hash(),"points":pts}
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()<1:
        quit(2)
        return
    var out:String=args[0]
    var render_on:bool=args.has("render")
    DirAccess.make_dir_recursive_absolute(out)
    if render_on:
        if not ClassDB.class_exists("PixelFXBodyRaster"):
            push_error("native raster required")
            quit(2)
            return
        raster=ClassDB.instantiate("PixelFXBodyRaster")
        body=Body.new()
    var clean=Session.new()
    var render_run=Session.new()
    var states:Array=[]
    var events:Array=[]
    for t in 130:
        states.append(clean.save())
        var cmd:Dictionary=command(t)
        clean.step(cmd)
        render_run.step(cmd)
        if render_on:render_probe(render_run)
        check(clean.save()==render_run.save() and clean.events==render_run.events,"independent repeat / render invariance")
        check(not clean.last_rejected,"accepted command trajectory")
        var a=clean.actor
        if a.fired and not clean.events.is_empty():
            # Diagnostic only: optional gate of |Z| <= 6 at sampled event
            # endpoint, NOT swept 3D capsule and never gameplay authority.
            var xy:bool=a.diagnostic.hit
            var depth:bool=xy and absf(Vector3(a.diagnostic.tip).z)<=6.
            if xy!=depth:depth_differences+=1
        events.append_array(clean.events.duplicate(true))
        trace.append(sample(clean))
        max_bytes=maxi(max_bytes,clean.save().size())
    check(clean.serial==3 and events.size()==3,"three attacks / one event each")
    # Restore fresh instances from before chamber, impact, post-event,
    # landing and a pending-tuning update, then compare every future tick.
    for t in [0,1,4,10,12,13,14,17,26,36,40,41,45,55,60,80,85,100,120]:
        var fresh=Session.new()
        check(fresh.restore(states[t]),"restore")
        check(fresh.save()==states[t],"lossless checkpoint roundtrip")
        for n in range(t,130):
            fresh.step(command(n))
            check(fresh.exact_hash()==trace[n].exact and fresh.events==trace[n].events,"fresh restore suffix exact "+str(t))
        restores+=1
    var predicted=Session.new()
    var history=History.new(predicted,140)
    for t in 130:check(history.advance(command(t,false)),"history advance")
    check(predicted.exact_hash()!=clean.exact_hash(),"prediction intentionally wrong")
    check(history.correct(3,command(3)),"late tuning correction")
    corrections+=1
    check(predicted.save()==clean.save(),"rollback converges byte for byte")
    var confirmed:Array=history.confirm_through(129)
    check(confirmed==events,"confirmed event ledger exact")
    check(history.confirm_through(129).is_empty(),"no duplicate event delivery")
    check(not history.correct(3,command(3,false)),"confirmed correction rejected")
    var bounded=History.new(Session.new(),2)
    check(bounded.advance({}) and bounded.advance({}) and not bounded.advance({}),"bounded history")
    bounded.confirm_through(0)
    check(bounded.advance({}),"ring reuse")
    var report:Dictionary={"ticks":130,"restores":restores,"corrections":corrections,"confirmed_events":events.size(),"max_snapshot_bytes":max_bytes,"rendered":rendered,"depth_endpoint_differences":depth_differences,"physics_backend":"none","failures":failures}
    for item in [["metrics.json",report],["trace.json",trace]]:
        var file:=FileAccess.open(out.path_join(item[0]),FileAccess.WRITE)
        file.store_string(JSON.stringify(item[1], "", true, true))
        file.close()
    print("SPATIAL_REPLAY_006 ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
