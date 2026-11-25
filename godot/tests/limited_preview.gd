extends SceneTree
# Lab 0.40: retarget N 0.10.3h reference poses onto the real Lab humanoid.
# Reference coordinates were manually estimated from a sprite sheet, not measured motion capture.
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const SKIN=preload("res://addons/creature/skin.gd")
const PAIN_KEYS=[
    [[73,85],[62,54],[59,20],[70,52],[99,64],[93,57],[53,48],[29,36],[44,37],[76,85],[88,105],[78,130],[65,86],[65,104],[42,128]],
    [[75,87],[102,61],[111,36],[113,56],[133,55],[154,56],[95,62],[85,76],[74,72],[78,87],[87,104],[51,104],[67,87],[46,105],[19,115]],
    [[66,87],[82,55],[94,27],[86,53],[103,72],[108,66],[75,48],[57,64],[72,75],[75,88],[88,105],[66,131],[60,85],[56,109],[62,123]],
    [[75,94],[99,61],[113,43],[102,59],[116,72],[119,94],[91,52],[67,44],[62,54],[80,96],[79,117],[62,112],[70,94],[58,111],[42,125]],
    [[82,78],[91,56],[106,46],[93,59],[99,83],[89,104],[86,51],[76,27],[57,30],[83,80],[73,109],[55,119],[74,80],[56,111],[36,134]],
    [[63,82],[68,51],[64,22],[72,49],[81,28],[65,15],[59,48],[53,67],[64,72],[68,83],[82,95],[72,97],[57,84],[52,109],[35,132]],
    [[64,78],[55,49],[38,31],[62,48],[83,49],[93,66],[49,48],[43,66],[15,68],[68,82],[80,95],[64,107],[57,83],[48,112],[45,137]],
    [[54,85],[43,56],[32,30],[43,48],[51,68],[39,77],[31,47],[16,67],[15,49],[58,82],[88,63],[122,48],[51,88],[40,109],[57,116]]
]
const PASSIVE_KEYS=[
    [12, 100,-115, 110,-105, 65,55, 95,40],
    [24, 95,-100, 130,-85, 62,65, 100,40],
    [32, 115,-105, 150,-75, 80,85, 128,32],
    [42, 95,-110, 120,-90, 48,95, 100,65],
    [52, 105,-100, 205,-65, 75,80, 120,35],
    [60, 100,-110, 150,-85, 48,100, 112,36],
    [68, 120,-95, 155,-35, 45,95, 100,45],
    [76, 110,-115, 125,-95, 5,0, 75,85],
    [82, 100,-115, 110,-105, 25,55, 82,80],
    [96, 90,-115, 108,-100, 60,75, 85,55],
    [112, 100,-115, 110,-105, 65,55, 95,40]
]
# Time in 120 Hz ticks, source key, original N root travel, added hit-stop.
# All impact keys are shared by both takes. Root follows its own authored curve.
const BEATS=[
    [0,-1,365,379,0],[12,-1,365,379,0],[24,0,391,359,0],
    [32,1,438,335,4],[42,2,460,326,0],[48,3,477,328,0],
    [52,4,489,335,6],[60,5,502,337,0],[68,6,518,341,0],
    [76,7,552,348,8],[82,7,557,355,0],[96,2,575,372,0],[112,-1,585,379,0]
]
const OMIT=[12,42,60,82]
const DURATION=130.0/120.0
const TRAVEL_SCALE=.42
const GUARD={"hips":0,"chest":0,"head":0,"shoulder_near":-44,"elbow_near":-70,"shoulder_far":24,"elbow_far":-90,"thigh_near":-23,"knee_near":30,"thigh_far":18,"knee_far":-27}
const CHAINS=[
    ["shoulder_near","elbow_near","hand_near",3,4,5,"chest"],
    ["shoulder_far","elbow_far","hand_far",6,7,8,"chest"],
    ["thigh_near","knee_near","foot_near",9,10,11,"hips"],
    ["thigh_far","knee_far","foot_far",12,13,14,"hips"]
]
class Board extends Node2D:
    var rig=RIG.humanoid()
    var clips:Array=[]
    var roots:Dictionary={}
    var t:float=0
    var hits:Array=[]
    func _draw()->void:
        draw_rect(Rect2(0,0,960,540),Color("#14212b"))
        draw_string(ThemeDB.fallback_font,Vector2(16,28),"LAB 0.40 / THREE-HIT AIR COMBO",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("#e6edf3"))
        for i in range(2):
            var x:float=12+474*i
            var y:float=44
            draw_rect(Rect2(x,y,462,453),Color("#213542"))
            var label:String="D  Directed holds" if i==0 else "E  Reduced poses"
            draw_string(ThemeDB.fallback_font,Vector2(x+13,y+26),label,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("#e6edf3"))
            draw_string(ThemeDB.fallback_font,Vector2(x+13,y+47),"%d unique keys / stepped bones"%int(clips[i].get("authored_keys",0)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#aebec9"))
            var floor_y:float=y+385
            draw_line(Vector2(x+15,floor_y),Vector2(x+447,floor_y),Color("#83988f"),1.0)
            var p:Dictionary=CLIPS.sample(clips[i],t,false)
            var root_pose:Dictionary=CLIPS.sample(roots,t,false)
            p.root=root_pose.root.duplicate()
            rig.evaluate(p)
            # Keep feet from clipping through the floor; flight and root track are shared.
            p.root[1]-=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
            rig.evaluate(p)
            draw_set_transform(Vector2(x+59,floor_y),0,Vector2(3.1,3.1))
            SKIN.draw_body(self,rig,Vector2.ZERO,1,Color("#5aafdc"),false)
            draw_set_transform(Vector2.ZERO)
            draw_rect(Rect2(x+15,y+414,432,5),Color("#405565"))
            draw_rect(Rect2(x+15,y+414,432*t/DURATION,5),Color("#78b7d3"))
            for k in clips[i].keys:
                var px:float=x+15+432*float(k.t)/DURATION
                draw_line(Vector2(px,y+409),Vector2(px,y+424),Color("#d6c6a1"),1.0)
            for j in range(hits.size()):
                var hx:float=x+15+432*float(hits[j])/DURATION
                draw_line(Vector2(hx,y+405),Vector2(hx,y+431),Color("#f0a65c"),2)
                draw_string(ThemeDB.fallback_font,Vector2(hx-5,y+443),str(j+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#f0a65c"))
        draw_string(ThemeDB.fallback_font,Vector2(16,522),"Native Lab rig / skin / sampler  |  Shared root & three impact poses  |  %.0f ms"%(t*1000),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#b4c2cc"))
func _initialize()->void:
    call_deferred("_run")
func _point(raw:Array,i:int)->Vector2:
    return Vector2(float(raw[i][0]),float(raw[i][1]))
func _passive(t:int,channel:int)->Vector2:
    var col:int=1+channel*2
    for i in range(1,PASSIVE_KEYS.size()):
        var a:Array=PASSIVE_KEYS[i-1]
        var b:Array=PASSIVE_KEYS[i]
        if t>int(b[0]):continue
        var u:float=smoothstep(float(a[0]),float(b[0]),float(t))
        return Vector2(lerpf(float(a[col]),float(b[col]),u),lerpf(float(a[col+1]),float(b[col+1]),u))
    return Vector2(float(PASSIVE_KEYS[-1][col]),float(PASSIVE_KEYS[-1][col+1]))
func _retarget(rig,idx:int,t:int)->Dictionary:
    if idx<0:return GUARD.duplicate(true)
    var raw:Array=PAIN_KEYS[idx]
    var hip:float=wrapf((_point(raw,1)-_point(raw,0)).angle()+PI*.5,-PI,PI)
    var neck:float=wrapf((_point(raw,2)-_point(raw,1)).angle()+PI*.5,-PI,PI)
    var chest:float=lerp_angle(hip,neck,.55)
    var angles:Dictionary={"hips":rad_to_deg(hip),"chest":rad_to_deg(wrapf(chest-hip,-PI,PI)),"head":rad_to_deg(-chest*.45)}
    for ch in range(CHAINS.size()):
        var c:Array=CHAINS[ch]
        var d1:Vector2=_point(raw,int(c[4]))-_point(raw,int(c[3]))
        var d2:Vector2=_point(raw,int(c[5]))-_point(raw,int(c[4]))
        var upper:float=d1.angle()
        var bend:float=d1.angle_to(d2)
        # Maintain active near arm/leg from the source. Correct other limbs with N's authored passive angles.
        var active:bool=(ch==0 and t>=24 and t<=52) or (ch==2 and t>=68 and t<=82)
        if not active:
            var pas:Vector2=_passive(t,ch)
            upper=deg_to_rad(pas.x)+hip*(.30 if ch>=2 else .55)
            bend=deg_to_rad(pas.y)
        var off1:Vector2=rig.joints[rig.ids[c[1]]].offset
        var off2:Vector2=rig.joints[rig.ids[c[2]]].offset
        var parent:float=hip if ch>=2 else chest
        var world_upper:float=upper-off1.angle()
        var world_lower:float=upper+bend-off2.angle()
        angles[c[0]]=rad_to_deg(wrapf(world_upper-parent,-PI,PI))
        angles[c[1]]=rad_to_deg(wrapf(world_lower-world_upper,-PI,PI))
    return angles
func _build()->Dictionary:
    var rig=RIG.humanoid()
    rig.evaluate(CLIPS.pose(GUARD))
    var ground:float=-maxf(rig.point("foot_near").y,rig.point("foot_far").y)
    var directed:Dictionary={"duration":DURATION,"loop":false,"keys":[],"events":[],"easing":"snap","authored_keys":BEATS.size()}
    var reduced:Dictionary=directed.duplicate(true)
    reduced.authored_keys=BEATS.size()-OMIT.size()
    var root_track:Dictionary={"duration":DURATION,"loop":false,"keys":[],"events":[],"easing":"smooth"}
    var hits:Array=[]
    var extra:int=0
    for beat in BEATS:
        var tick:int=int(beat[0])
        var t:float=float(tick+extra)/120.0
        var angles:Dictionary=_retarget(rig,int(beat[1]),tick)
        var p:Dictionary=CLIPS.pose(angles)
        var k:Dictionary={"t":t,"pose":p,"easing":"snap"}
        directed.keys.append(k)
        if not OMIT.has(tick):reduced.keys.append(k.duplicate(true))
        var rp:Dictionary=CLIPS.pose({},(float(beat[2])-365.0)*TRAVEL_SCALE,ground+(float(beat[3])-379.0)*TRAVEL_SCALE)
        root_track.keys.append({"t":t,"pose":rp,"easing":"smooth"})
        var stop:int=int(beat[4])
        if stop>0:
            hits.append(t)
            var ev:Dictionary={"t":t,"kind":"strike","anchor":"foot_near" if tick==76 else "hand_near"}
            directed.events.append(ev)
            reduced.events.append(ev.duplicate(true))
            extra+=stop
            root_track.keys.append({"t":float(tick+extra)/120.0,"pose":rp.duplicate(true),"easing":"snap"})
    return {"clips":[directed,reduced],"roots":root_track,"hits":hits}
func _run()->void:
    root.size=Vector2i(960,540)
    var board=Board.new()
    var bundle:Dictionary=_build()
    board.clips=bundle.clips
    board.roots=bundle.roots
    board.hits=bundle.hits
    root.add_child(board)
    await process_frame
    var out:String=ProjectSettings.globalize_path("res://../reports/limited")
    DirAccess.make_dir_recursive_absolute(out)
    for t in bundle.hits:
        if CLIPS.sample(board.clips[0],t,false)!=CLIPS.sample(board.clips[1],t,false):
            push_error("Impact pose drift");quit(1);return
    if bundle.hits.size()!=3 or board.clips[1].keys.size()>=board.clips[0].keys.size():
        push_error("Combo cadence invalid");quit(1);return
    var data=FileAccess.open(out.path_join("clips.json"),FileAccess.WRITE)
    data.store_string(JSON.stringify(bundle,"  ",true,true))
    data.close()
    for i in range(78):
        board.t=clampf(float(i-5)/60.0,0,DURATION)
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(out.path_join("frame_%03d.png"%i))!=OK:
            push_error("PNG save failed");quit(1);return
    print("LAB native air combo OK: 78 frames; directed 13 / reduced 9; three equal impact poses")
    quit()
