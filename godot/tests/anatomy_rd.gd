extends SceneTree
const RIG=preload("res://addons/creature/rig.gd")
const POSE=preload("res://lab/anatomy_rd/pose.gd")
const INK=preload("res://lab/temporal_rd/ink.gd")
const VAL=preload("res://addons/creature/sdk_validate.gd")
const WIDTH=360
const HEIGHT=225
const SCALE=3.5
const FLOOR=207.0
const ORIGIN=93.0
const GAP=37.0
const HIT=15
const LAST=42
const ZERO=[0,0,0,0,0]
class Board extends Node2D:
    var pairs:Array=[]
    var stance:Array=[]
    var tick:int=0
    func paint_actor(s:Dictionary,at:Vector2,flip:float)->void:
        var q:={}
        for id in s.points:
            q[id]=Vector2(s.points[id][0],s.points[id][1])
        draw_set_transform(at,0,Vector2(flip*SCALE,SCALE))
        INK.actor(self,q,0,"hand_near")
        draw_set_transform(Vector2.ZERO)
    func _draw()->void:
        if not stance.is_empty():
            for i in stance.size():
                var x:=float(i*240)
                draw_rect(Rect2(x,0,240,HEIGHT),Color("#273b4b"))
                draw_line(Vector2(x+8,FLOOR),Vector2(x+232,FLOOR),Color("#738a8f"))
                paint_actor(stance[i],Vector2(x+120,FLOOR),1.0)
            return
        for i in pairs.size():
            var x:=float(i*WIDTH)
            draw_rect(Rect2(x,0,WIDTH,HEIGHT),Color("#273b4b"))
            draw_line(Vector2(x+8,FLOOR),Vector2(x+WIDTH-8,FLOOR),Color("#738a8f"))
            paint_actor(pairs[i][1],Vector2(x+ORIGIN+GAP*SCALE,FLOOR),-1.0)
            paint_actor(pairs[i][0],Vector2(x+ORIGIN,FLOOR),1.0)
            # No VFX hiding posture. A small contact mark only on event frame.
            if tick==HIT:
                var h:Array=pairs[i][0].points.hand_near
                draw_arc(Vector2(x+ORIGIN+h[0]*SCALE,FLOOR+h[1]*SCALE),9,0,TAU,20,Color("#f3d37d"),1.5)
static func point(s:Dictionary,id:String)->Vector2:
    return Vector2(s.points[id][0],s.points[id][1])
static func metrics(samples:Array)->Dictionary:
    var bad_knee:=0
    var bad_elbow:=0
    var floor_pen:=0.0
    var plant:=0.0
    var cross_legs:=0
    for s in samples:
        plant=maxf(plant,s.plant)
        for side in ["near","far"]:
            var a:=point(s,"thigh_"+side)
            var b:=point(s,"knee_"+side)
            var c:=point(s,"foot_"+side)
            if (c-a).cross(b-a) > .01:bad_knee+=1
            if b.y>0.0:floor_pen=maxf(floor_pen,b.y)
            var sh:=point(s,"shoulder_"+side)
            var el:=point(s,"elbow_"+side)
            var hand:=point(s,"hand_"+side)
            if hand.x>sh.x and (hand-sh).cross(el-sh)<-.01:bad_elbow+=1
        if point(s,"knee_near").x < point(s,"knee_far").x:cross_legs+=1
    return {"backward_knee_joint_frames":bad_knee,"upward_elbow_joint_frames":bad_elbow,"knee_order_inverted_frames":cross_legs,"floor_knee_penetration":floor_pen,"plant_error":plant}
func save_clip(out:String,id:String,slot:String,seq:Array,event:bool)->bool:
    var clip:={"duration":LAST/60.0,"loop":false,"easing":"linear","keys":[],"events":[]}
    if event:clip.events.append({"t":HIT/60.0,"kind":"strike","anchor":"hand_near"})
    for i in seq.size():clip.keys.append({"t":i/60.0,"pose":seq[i].pose})
    var entry:={"schema":1,"id":id,"kind":"animation","name":id,"source":"authored","payload":{"slot":slot,"clip":clip}}
    var report:Dictionary=VAL.new().validate(entry)
    if not report.ok:
        push_error(JSON.stringify(report));return false
    var f:=FileAccess.open(out.path_join(id+".json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(entry,"",true,true));f.close()
    return true
func _initialize()->void:call_deferred("run")
func run()->void:
    var args:=OS.get_cmdline_user_args()
    if args.size()!=1:quit(2);return
    var out:String=args[0]
    DirAccess.make_dir_recursive_absolute(out)
    var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://lab/anatomy_rd/briefs.json"))
    var old:Array=JSON.parse_string(FileAccess.get_file_as_string("res://lab/temporal_rd/briefs.json"))
    var rig=RIG.humanoid()
    var board:=Board.new()
    root.add_child(board)
    var legacy:Dictionary=data.punch.duplicate(true)
    legacy.poles=[1,-1,1,-1]
    var bad_receiver:Dictionary=data.recoil.duplicate(true)
    bad_receiver.poles=[1,-1,1,-1]
    var size:=Vector2i(720,HEIGHT)
    root.content_scale_size=size
    root.size=size
    board.stance=[POSE.sample(rig,old[0],0,ZERO),POSE.sample(rig,legacy,0,ZERO),POSE.sample(rig,data.punch,0,ZERO)]
    board.queue_redraw()
    await process_frame
    await RenderingServer.frame_post_draw
    var still:=root.get_texture().get_image()
    if still.get_size()!=size or still.save_png(out.path_join("stance.png"))!=OK:quit(1);return
    board.stance=[]
    var aa:Array=[]
    var bb:Array=[]
    var ba:Array=[]
    var br:Array=[]
    for t in range(LAST+1):
        var a:Dictionary=POSE.sample(rig,legacy,t,ZERO)
        var b:Dictionary=POSE.sample(rig,data.punch,t,ZERO)
        var ar:Dictionary=POSE.sample(rig,bad_receiver,t,ZERO)
        var rr:Dictionary=POSE.sample(rig,data.recoil,t,ZERO)
        aa.append(a);bb.append(b);ba.append(ar);br.append(rr)
        board.pairs=[[a,ar],[b,rr]]
        board.tick=t
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        var img:=root.get_texture().get_image()
        if img.get_size()!=size or img.save_png(out.path_join("%03d.png"%t))!=OK:quit(1);return
    var hand:=point(bb[HIT],"hand_near")
    var torso:=point(br[HIT],"chest")
    var contact:=hand.distance_to(Vector2(GAP-torso.x,torso.y))
    var report:={"legacy_attacker":metrics(aa),"new_attacker":metrics(bb),"legacy_receiver":metrics(ba),"new_receiver":metrics(br),"contact_center_distance":contact,"contact_tick":HIT,"frame_count":LAST+1,"fps":60}
    var f:=FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "));f.close()
    if not save_clip(out,"anatomy_punch","strike",bb,true) or not save_clip(out,"anatomy_recoil","hurt",br,false):quit(1);return
    print("ANATOMY_OK ",JSON.stringify(report))
    quit()
