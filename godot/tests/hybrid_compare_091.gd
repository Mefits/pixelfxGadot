extends "res://tests/hybrid_091.gd"
const LegacyAction=preload("res://lab/leg_transition_082.gd")
func _initialize():
    var out:String=OS.get_cmdline_user_args()[0]
    rate=60
    var raster=ClassDB.instantiate("PixelFXBodyRaster")
    run_clip=JSON.parse_string(FileAccess.get_file_as_string(FIX+"run053a_C.json")).payload.clip
    var clip:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIX+"combo052a2_B.json")).payload.clip
    bank={"jab":Motion.compile(clip,0,38,CHANNELS,rate),"cross":Motion.compile(clip,23,45,CHANNELS,rate)}
    guard=bank.jab.frames[0]
    var player=new_player()
    var ref=Body.make_rig()
    var gait=Old.new(ref,run_clip)
    gait.polish=true
    var legacy=LegacyAction.new(ref,2)
    var rows:Array=[]
    var legacy_marks:Array=[]
    var peak_old:=0.
    var peak_new:=0.
    var locks:Array=[{},{}]
    var drift:Array=[0.,0.]
    var old_points:Dictionary={}
    var new_points:Dictionary={}
    for t in 245:
        var cmd:=command(t)
        player.step(cmd)
        var p:Dictionary
        var w:float=0.
        if t<112:
            gait.advance(player.speed)
            var sample:Dictionary=gait.sample()
            p=sample.pose
            w=sample.gait
            legacy.previous=legacy.current
            legacy.current=p
        else:
            if t in [112,137,160]:
                var first:int={112:0,137:23,160:0}[t]
                var last:int={112:38,137:45,160:0}[t]
                legacy.command({"name":str(t),"clip":clip,"first":first,"last":last,"loop":false})
            var sample:Dictionary=legacy.step()
            p=sample.pose
            for marker in sample.events:legacy_marks.append([t,marker.anchor])
        ref.evaluate(p)
        if t<112:
            for i in 2:
                var side:String=Leg.SIDES[i]
                var old_toe:Vector2=ref.point("foot_"+side)+IK.toe_vector(p,side)+Vector2.RIGHT*gait.travel
                var new_toe:Vector2=player.rig.point("foot_"+side)+IK.toe_vector(player.final_pose,side)+Vector2.RIGHT*player.gait.travel
                var toes:=[old_toe,new_toe]
                for lane in 2:
                    if player.paths[i].stance:
                        if not locks[lane].has(side):locks[lane][side]=toes[lane]
                        drift[lane]=maxf(drift[lane],toes[lane].distance_to(locks[lane][side]))
                    else:locks[lane].erase(side)
        if t>=112:
            for id in ref.points:
                peak_old=maxf(peak_old,ref.point(id).distance_to(old_points[id]))
                peak_new=maxf(peak_new,player.rig.point(id).distance_to(new_points[id]))
        old_points=ref.points.duplicate()
        new_points=player.rig.points.duplicate()
        var a:=render(ref,p,w,raster)
        var b:=render(player.rig,player.final_pose,player.style,raster)
        require(a.save_png(out.path_join("old%03d.png"%t))==OK,"control capture")
        require(b.save_png(out.path_join("%03d.png"%t))==OK,"new capture")
        rows.append([gait.travel,player.gait.travel,player.events,player.stopped])
    FileAccess.open(out.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(rows))
    print("Same gait drift old/new ",drift)
    print("COMPARE ",legacy_marks," post-command peak joint step old/new ",peak_old," / ",peak_new)
    quit(1 if failed else 0)
