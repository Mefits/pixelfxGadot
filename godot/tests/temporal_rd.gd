extends SceneTree
# New temporal experiment. Baseline sampler copied from motif_search.gd.
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VAL=preload("res://addons/creature/sdk_validate.gd")
const INK=preload("res://lab/temporal_rd/ink.gd")
const TIPS=["hand_near","hand_far","foot_near","foot_far"]
const CHAINS={"hand_near":["shoulder_near","elbow_near"],"hand_far":["shoulder_far","elbow_far"],"foot_near":["thigh_near","knee_near"],"foot_far":["thigh_far","knee_far"]}
const TILE=192
const ZOOM=2.4
const FLOOR_Y=174.0
const ORIGIN_X=108.0

static func sample(rig,m:Dictionary,t:float,v:Array)->Dictionary:
    var keys:Array=m.keys
    var k:=0
    while k+1<keys.size() and t>=keys[k+1][0]: k+=1
    var a:Array=keys[k]
    var b:Array=keys[mini(k+1,keys.size()-1)]
    var u:=smoothstep(float(a[0]),float(b[0]),t) if a[0]!=b[0] else 0.0
    var w:Array=[0.0,-.75,-1.0,.55,1.0,1.0,.25,0.0]
    var weight:=lerpf(w[k],w[mini(k+1,w.size()-1)],u)
    if weight<0.0:weight*=1.0+float(v[4])*.32
    var hip:float=lerpf(a[3],b[3],u)+v[0]*weight
    var torso:float=lerpf(a[4],b[4],u)+v[1]*weight
    var pose:=CLIPS.pose({"hips":hip,"chest":torso-hip},lerpf(a[1],b[1],u),lerpf(a[2],b[2],u)+22)
    rig.evaluate(pose)
    var wanted:={}
    var targets:={}
    for i in 4:
        var tip:String=TIPS[i]
        var xy:=Vector2(a[5+i][0],a[5+i][1]).lerp(Vector2(b[5+i][0],b[5+i][1]),u)
        if i<2 and tip!=m.tip:
            xy+=Vector2(v[2],v[3])*weight*(1.0 if i==0 else -.65)
        var chain:Array=CHAINS[tip]
        var span:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
        var delta:Vector2=(xy-rig.point(chain[0]))/span
        targets[tip]=[delta.x,delta.y,1.0 if i in [0,2] else -1.0]
        wanted[tip]=xy
    pose.angles.head=-torso*.45
    rig.evaluate(pose)
    for tip in targets:
        var pair:Array=CHAINS[tip]
        var upper:Dictionary=rig.joints[rig.ids[pair[0]]]
        var first:Vector2=rig.joints[rig.ids[pair[1]]].offset
        var last:Vector2=rig.joints[rig.ids[tip]].offset
        var d:Array=targets[tip]
        var ray:=Vector2(d[0],d[1])
        var la:=first.length()
        var lb:=last.length()
        var reach:=clampf(ray.length()*(la+lb),absf(la-lb)+.0001,la+lb-.0001)
        var along:float=(la*la-lb*lb+reach*reach)/(2.0*reach)
        var axis:=ray.normalized()
        var mid:=axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,la*la-along*along))*float(d[2])
        var proximal:=mid.angle()-first.angle()
        var distal:=(axis*reach-mid).angle()-last.angle()
        pose.angles[pair[0]]=rad_to_deg(wrapf(proximal-float(rig.rotations[upper.parent]),-PI,PI))
        pose.angles[pair[1]]=rad_to_deg(wrapf(distal-proximal,-PI,PI))
    rig.evaluate(pose)
    var points:={}
    for id in rig.points:
        var p:Vector2=rig.point(id)
        points[id]=[p.x,p.y]
    var plant:=0.0
    for tip in ["foot_near","foot_far"]:
        if absf(wanted[tip].y)<.01:plant=maxf(plant,rig.point(tip).distance_to(wanted[tip]))
    return {"pose":pose,"points":points,"plant":plant,"anchor":rig.point(m.tip).distance_to(wanted[m.tip])}

class Board extends Node2D:
    var samples:Array=[]
    var active:String=""
    func _draw()->void:
        for i in samples.size():
            var col:=float(i*TILE)
            var q:={}
            for id in samples[i].points:
                var a:Array=samples[i].points[id]
                q[id]=Vector2(a[0],a[1])
            draw_rect(Rect2(col,0,TILE,TILE),Color("#273b4b"))
            draw_line(Vector2(col+4,FLOOR_Y),Vector2(col+TILE-4,FLOOR_Y),Color("#738a8f"))
            draw_rect(Rect2(col,TILE,TILE,TILE),Color.BLACK)
            for row in 2:
                draw_set_transform(Vector2(col+ORIGIN_X,FLOOR_Y+row*TILE),0,Vector2.ONE*ZOOM)
                INK.actor(self,q,row,active)
                draw_set_transform(Vector2.ZERO)

func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=2:quit(2);return
    var config:Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
    var out:String=args[1]
    var rig=RIG.humanoid()
    var board:=Board.new()
    root.add_child(board)
    for m in config:
        var candidates:Array=m.candidates
        var folder:=out.path_join(m.id)
        DirAccess.make_dir_recursive_absolute(folder)
        var size:=Vector2i(TILE*candidates.size(),TILE*2)
        root.content_scale_size=size
        root.size=size
        board.active=m.tip
        var report:Array=[]
        for i in candidates.size():report.append([])
        var last:int=m.keys[-1][0]
        for t in range(last+1):
            board.samples=[]
            for i in candidates.size():
                var c:Dictionary=candidates[i]
                var s:=sample(rig,c.motif,t,c.v)
                board.samples.append(s)
                report[i].append(s)
            board.queue_redraw()
            await process_frame
            await RenderingServer.frame_post_draw
            var img:=root.get_texture().get_image()
            if img.get_size()!=size or img.save_png(folder.path_join("%03d.png"%t))!=OK:
                push_error("Capture failed");quit(1);return
        var f:=FileAccess.open(folder.path_join("tracks.json"),FileAccess.WRITE)
        f.store_string(JSON.stringify(report))
        f.close()
        for i in candidates.size():
            var c:Dictionary=candidates[i]
            var clip:={"duration":last/60.0,"loop":false,"easing":"linear","keys":[],"events":[]}
            if m.id in ["rise","sweep"]:clip.events.append({"t":m.keys[4][0]/60.0,"kind":"strike","anchor":m.tip})
            for t in range(last+1):clip.keys.append({"t":t/60.0,"pose":report[i][t].pose})
            var slot: String={"rise":"strike","sweep":"kick","brace":"guard","evade":"jump"}[m.id]
            var entry:={"schema":1,"id":"temporal_"+m.id,"kind":"animation","name":m.title,"source":"authored","payload":{"slot":slot,"clip":clip}}
            if not VAL.new().validate(entry).ok:
                push_error("Invalid SDK clip: "+m.id+" "+str(i));quit(1);return
            var cf:=FileAccess.open(folder.path_join("clip_%02d.json"%i),FileAccess.WRITE)
            cf.store_string(JSON.stringify(entry,"",true,true))
            cf.close()
    print("TEMPORAL_OK")
    quit()
