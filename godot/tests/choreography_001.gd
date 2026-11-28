extends SceneTree
const Player=preload("res://lab/authoring/choreography/player.gd")
const Training=preload("res://lab/training_control.gd")
const Idle=preload("res://lab/spatial_lab/spatial_idle_013.gd")
const Seq=preload("res://lab/spatial_lab/spatial_kick_014.gd")
const Body=preload("res://lab/spatial_lab/spatial_body.gd")
const CFG=preload("res://lab/hybrid_studio.gd").CFG
var digest=HashingContext.new()
var failures:Array=[]
var rig_body=Body.new()
var raster
var out:String
var max_floor:=0.
var max_ik:=0.
var snapshot_bytes:=0
var max_step:=0.
var max_bone:=0.
var max_anchor:=0.
func check(ok:bool,msg:String)->void:
    if not ok and not failures.has(msg):failures.append(msg)
func capture(r,art:Dictionary,lane:int,tick:int)->void:
    if out.is_empty():return
    var cfg:Dictionary=CFG.duplicate(true)
    cfg.height=340
    cfg.origin=[210,285]
    var result:Dictionary=raster.render(cfg,rig_body.make(r,art))
    if not result.get("ok",false):
        check(false,"raster")
        return
    var im:=Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)
    check(im.save_png(out.path_join("%d-near-%03d.png"%[lane,tick]))==OK,"PNG")
func _initialize():call_deferred("run")
func run():
    digest.start(HashingContext.HASH_SHA256)
    var args=OS.get_cmdline_user_args()
    if args.size():
        out=args[0]
        DirAccess.make_dir_recursive_absolute(out)
        raster=ClassDB.instantiate("PixelFXBodyRaster")
    var base=Training.new().walker.pose
    var idle=Idle.new()
    idle.mode=3
    idle.setup(base)
    var ref=Seq.new()
    ref.setup(base,2,17)
    for t in 108:
        check(ref.step(t).accepted,"014 B")
        capture(ref.rig,ref.current.pose,1,t)
    for i in 2:
        var id=["wheel","hook"][i]
        var d=Player.Asset.read("res://lab/authoring/choreography/"+id+".json")
        var copy:Dictionary=d.duplicate(true)
        copy.id="choreo_roundtrip_"+id
        check(Player.Asset.persist(copy)==OK and Player.Asset.read(Player.Asset.FOLDER+copy.id+".json")==copy,"roundtrip")
        DirAccess.remove_absolute(Player.Asset.FOLDER+copy.id+".json")
        for start_phase in [0,17,33]:
            var p=Player.new()
            for t in 12:
                idle.idle(start_phase+t-12)
                if start_phase==17:capture(idle.rig,base,2+i,t)
            var prior=Player.Entry.sample(idle.rig,base)
            idle.idle(start_phase)
            var now=Player.Entry.sample(idle.rig,base)
            check(p.start(d,now,prior,42),"start")
            var saved
            var count:=0
            var peak:=0.
            var n:int=p.frames.size()
            for t in n:
                if not p.step():
                    check(false,"step %s %d"%[id,t])
                    break
                if t==0:check(p.rig.point3("hips").distance_to(now.root)<.01,"entry")
                max_floor=maxf(max_floor,maxf(p.current.toes.near.y,p.current.toes.far.y))
                max_ik=maxf(max_ik,p.target_error)
                if t==25:
                    saved=p.save()
                    snapshot_bytes=maxi(snapshot_bytes,saved.size())
                for joint in p.rig.ids_in_order():
                    var par=p.rig.parent_id(joint)
                    if par!="":max_bone=maxf(max_bone,absf(p.rig.point3(joint).distance_to(p.rig.point3(par))-p.rig.rest_offset_xyz(joint).length()))
                    max_step=maxf(max_step,p.rig.point3(joint).distance_to(p.previous.xyz[joint]))
                if p.side!="air":max_anchor=maxf(max_anchor,p.current.toes[p.side].distance_to(p.solver.contacts[p.side].anchor))
                else:peak=maxf(peak,-maxf(p.current.toes.near.y,p.current.toes.far.y))
                digest.update(var_to_bytes([p.current.xyz,p.current.yaw,p.events]))
                count+=p.events.size()
                if start_phase==17:capture(p.rig,p.art,2+i,12+t)
            check(peak>5. and count==1 and absf(p.current.yaw-now.yaw)==65536,"flight / winding / marker")
            var end=p.save()
            if saved!=null and p.restore(saved):
                while p.age<n-1:
                    if not p.step():break
                check(p.save()==end,"replay")
            else:check(false,"restore")
            if start_phase==17:
                # Reuse the 014 recovery receiver, locating D at the last plant.
                var recovery=Player.Entry.new(p.current,p.previous)
                var dest=ref.idle_sample(start_phase+n)
                var shift:Vector3=p.current.toes[p.side]-dest.toes[p.side]
                var winding:=roundi(float(p.current.yaw-dest.yaw)/65536.)*65536
                for t in range(12+n,108):
                    var age:=t-(12+n)+1
                    var target=ref.idle_sample(start_phase+n+age,shift,winding)
                    var display=recovery.blend(ref.desired,target,age,12)
                    var support=Player.Support.new()
                    support.capture(ref.desired,display,p.side,Player.Support.PIVOT)
                    support.contacts[p.side].anchor=p.current.toes[p.side]
                    check(support.resolve_evaluated(ref.rig,ref.desired,16.).accepted,"exit")
                    capture(ref.rig,display,2+i,t)
            var history=preload("res://lab/hybrid091/history.gd").new(p,96)
            p.restore(saved)
            history.confirmed=p.tick-1
            for z in range(p.tick,n):check(history.advance({}),"history")
            check(history.correct(27,{}),"history restore")
            var released=history.confirm_through(n)
            check(released.size()==1 and history.confirm_through(n).is_empty(),"confirmed once")
            var old=p.current
            var other=Player.Asset.read("res://lab/authoring/choreography/"+["hook","wheel"][i]+".json")
            p.restore(saved)
            old=p.current
            check(p.start(other,old,p.previous,43) and p.step() and p.current.root.distance_to(old.root)<.01,"direct interrupt")
            for z in range(1,p.frames.size()):
                if not p.step():
                    check(false,"interrupted sequence "+str(z))
                    break
    check(max_bone<.001 and max_anchor<.001 and max_step<30. and max_floor<.002 and max_ik<.002,"geometry")
    print("TRACE ",digest.finish().hex_encode())
    print("CHOREO_001 ",[max_bone,max_anchor,max_step,max_floor,max_ik,snapshot_bytes,failures])
    quit(0 if failures.is_empty() else 1)
