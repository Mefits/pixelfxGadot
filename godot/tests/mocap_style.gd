extends SceneTree
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VALID=preload("res://addons/creature/sdk_validate.gd")
const INK=preload("res://lab/anatomy_rd/ink_readable.gd")
const CHAINS={"hand_near":["shoulder_near","elbow_near"],"hand_far":["shoulder_far","elbow_far"],"foot_near":["thigh_near","knee_near"],"foot_far":["thigh_far","knee_far"]}
static func solve(rig,pose:Dictionary,targets:Dictionary)->Dictionary:
    rig.evaluate(pose)
    for tip in targets:
        var chain:Array=CHAINS[tip]
        var upper:Dictionary=rig.joints[rig.ids[chain[0]]]
        var first:Vector2=rig.joints[rig.ids[chain[1]]].offset
        var last:Vector2=rig.joints[rig.ids[tip]].offset
        var d:Array=targets[tip]
        var ray:=Vector2(d[0],d[1])
        if ray.length_squared()<.000001:ray=Vector2.DOWN*.01
        var a:=first.length()
        var b:=last.length()
        var reach:=clampf(ray.length()*(a+b),absf(a-b)+.0001,a+b-.0001)
        var along:float=(a*a-b*b+reach*reach)/(2.0*reach)
        var axis:=ray.normalized()
        var mid:=axis*along+axis.orthogonal()*sqrt(maxf(0,a*a-along*along))*float(d[2])
        # Vector2.orthogonal is clockwise in Godot; use explicit sign matching source cross.
        mid=axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,a*a-along*along))*float(d[2])
        var proximal:=mid.angle()-first.angle()
        var distal:=(axis*reach-mid).angle()-last.angle()
        pose.angles[chain[0]]=rad_to_deg(wrapf(proximal-float(rig.rotations[upper.parent]),-PI,PI))
        pose.angles[chain[1]]=rad_to_deg(wrapf(distal-proximal,-PI,PI))
    rig.evaluate(pose)
    return pose
class Board extends Node2D:
    var pts:Array=[]
    func _draw()->void:
        for i in pts.size():
            var x:=float(i*240)
            draw_rect(Rect2(x,0,240,230),Color("#273b4b"))
            draw_line(Vector2(x+4,210),Vector2(x+236,210),Color("#738a8f"))
            draw_set_transform(Vector2(x+103,210),0,Vector2.ONE*3.4)
            INK.actor(self,pts[i],0,"hand_near")
            draw_set_transform(Vector2.ZERO)
func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    var out:String=args[0]
    var cfg:Array=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("config.json")))
    var rig=RIG.humanoid()
    var board:=Board.new()
    root.add_child(board)
    root.content_scale_size=Vector2i(960,230)
    root.size=Vector2i(960,230)
    var all_points:Array=[]
    var report:Array=[]
    var count:=0
    for i in cfg.size():
        var v:Dictionary=cfg[i]
        var poses:Array=[]
        var keys:Array=[]
        var max_pen:=0.0
        var max_root_adjust:=0.0
        var locks:Dictionary={}
        for t in v.frames.size():
            var f:Dictionary=v.frames[t]
            var tilt:float=clampf(f.tilt,-65,65)
            var p:=CLIPS.pose({"hips":tilt*.25,"chest":tilt*.75,"head":-tilt*.45},f.root[0],f.root[1])
            p=solve(rig,p,f.targets)
            # Foot correction uses actual source ankle height and a fixed planted point.
            var goals:Dictionary={}
            for j in 2:
                var tip:String=["foot_near","foot_far"][j]
                var foot:Array=f.feet[j]
                var support:bool=absf(foot[1])<=1.8
                if support:
                    if not locks.has(tip):locks[tip]=Vector2(rig.point(tip).x,0)
                    goals[tip]=locks[tip]
                else:
                    locks.erase(tip)
                    if rig.point(tip).y>0:goals[tip]=Vector2(rig.point(tip).x,0)
            var shift:=Vector2.ZERO
            for iteration in 12:
                for tip in goals:
                    var chain:Array=CHAINS[tip]
                    var center:Vector2=goals[tip]-rig.point(chain[0])
                    var reach:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()-.002
                    if shift.distance_to(center)>reach:shift=center+(shift-center).limit_length(reach)
            p.root[0]+=shift.x
            p.root[1]+=shift.y
            max_root_adjust=maxf(max_root_adjust,shift.length())
            rig.evaluate(p)
            var targets:Dictionary={}
            for tip in goals:
                var chain:Array=CHAINS[tip]
                var span:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
                var ray:Vector2=(goals[tip]-rig.point(chain[0]))/span
                targets[tip]=[ray.x,ray.y,f.targets[tip][2]]
            p=solve(rig,p,targets)
            var penetration:=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            max_pen=maxf(max_pen,penetration)
            p.root[1]-=penetration
            rig.evaluate(p)
            poses.append(rig.points.duplicate())
            keys.append({"t":t/60.0,"pose":p})
        all_points.append(poses)
        count=maxi(count,poses.size())
        var clip:={"duration":float(keys.size()-1)/60.0,"loop":false,"easing":"linear","keys":keys,"events":[{"t":float(v.contact)/60.0,"kind":"strike","anchor":"hand_near"}]}
        var entry:={"schema":1,"id":"mocap_style_"+str(i),"name":v.label,"kind":"animation","source":"authored","payload":{"slot":"strike","clip":clip}}
        if not VALID.new().validate(entry).ok:push_error("Invalid SDK "+str(i));quit(1);return
        var file:=FileAccess.open(out.path_join("clip_"+str(i)+".json"),FileAccess.WRITE)
        file.store_string(JSON.stringify(entry));file.close()
        report.append({"variant":v.label,"duration":clip.duration,"contact_s":float(v.contact)/60.0,"frames":keys.size(),"floor_pen_before_final_clamp":max_pen,"root_adjustment_px":max_root_adjust})
    for t in count:
        board.pts=[]
        for v in all_points:board.pts.append(v[mini(t,v.size()-1)])
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.get_size()!=Vector2i(960,230) or img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    var f:=FileAccess.open(out.path_join("render-report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "));f.close()
    print("MOCAP_STYLE_OK")
    quit()
