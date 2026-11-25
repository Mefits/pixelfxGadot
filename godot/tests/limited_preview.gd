extends SceneTree
# Lab 0.42: preserve D baseline, compare purpose-authored choreography with the same flight and landing.
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

const LAUNCH=20
const LAND=106
const END=158
const DURATION=158.0/120.0
const FRAME_COUNT=104
const TRAVEL=68.0
const HEIGHT=26.0
const GUARD={"hips":0,"chest":0,"head":0,"shoulder_near":-44,"elbow_near":-70,"shoulder_far":24,"elbow_far":-90,"thigh_near":-23,"knee_near":30,"thigh_far":18,"knee_far":-27}
const CHAINS=[
    ["shoulder_near","elbow_near","hand_near",3,4,5,"chest"],
    ["shoulder_far","elbow_far","hand_far",6,7,8,"chest"],
    ["thigh_near","knee_near","foot_near",9,10,11,"hips"],
    ["thigh_far","knee_far","foot_far",12,13,14,"hips"]
]

# tick, pose id, optional impact anchor. -1 is guard; -2..-11 are new authored poses.
const BEATS=[
    [0,-1,""],[8,-2,""],[16,-2,""],[20,-3,""],[26,0,""],
    [34,1,"hand_near"],[40,1,""],[45,2,""],[50,-4,""],
    [56,-5,"hand_far"],[62,-5,""],[68,5,""],[74,6,""],
    [80,7,"foot_near"],[88,7,""],[94,-6,""],[100,-7,""],
    [106,-8,""],[114,-9,""],[126,-10,""],[140,-11,""],[158,-11,""]
]
# World-space segment directions (degrees, right=0, down=90).
# [pelvis tilt, torso tilt, near upper/lower arm, far upper/lower arm, near upper/lower leg, far upper/lower leg].
# F uses the same 22 exposure times as D; every changed airborne key has a deliberate silhouette.
const STAGED={
    26: [-14,-24,[145,8,108,-42,35,133,118,68]],
    34: [20,39,[-7,1,135,30,115,58,132,84]],
    40: [20,39,[-7,1,135,30,115,58,132,84]],
    45: [4,9,[67,-45,117,25,61,135,130,77]],
    50: [-21,-35,[82,-65,155,60,43,131,120,56]],
    56: [18,36,[138,30,-26,-21,120,48,49,135]],
    62: [18,36,[138,30,-26,-21,120,48,49,135]],
    68: [-19,-22,[82,-38,97,2,-34,110,115,73]],
    74: [-31,-38,[101,-18,130,15,-56,87,124,66]],
    80: [-36,-48,[147,62,128,38,-11,-8,107,161]],
    88: [-36,-48,[147,62,128,38,-11,-8,107,161]],
    94: [-12,-14,[111,12,127,40,36,116,111,79]]
}
# The reference rig is planar: counter-rotation here is pelvis/torso tilt,
# not a true out-of-plane twist. Both takes use the same native skin.
class Board extends Node2D:
    var rig=RIG.humanoid()
    var clips:Array=[]
    var feet:Dictionary={}
    var hits:Array=[]
    var t:float=0
    func _draw()->void:
        draw_rect(Rect2(0,0,960,540),Color("#14212b"))
        draw_string(ThemeDB.fallback_font,Vector2(16,27),"LAB 0.42 / AIR COMBO CHOREOGRAPHY",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#e6edf3"))
        var labels:Array=["D  Original choreography","F  Stronger staging"]
        for i in range(2):
            var x:float=12.0+474.0*i
            draw_rect(Rect2(x,44,462,453),Color("#213542"))
            draw_string(ThemeDB.fallback_font,Vector2(x+11,70),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#e6edf3"))
            var subtitle:String="%d keys / same cadence and landing"%clips[i].keys.size()
            draw_string(ThemeDB.fallback_font,Vector2(x+11,91),subtitle,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#aebec9"))
            var floor_y:float=405
            draw_line(Vector2(x+10,floor_y),Vector2(x+452,floor_y),Color("#83988f"),1)
            var p:Dictionary=get_tree()._sample_final(rig,clips[i],t,feet)
            rig.evaluate(p)
            draw_set_transform(Vector2(x+82,floor_y),0,Vector2(3.6,3.6))
            SKIN.draw_body(self,rig,Vector2.ZERO,1,Color("#5aafdc"),false)
            draw_set_transform(Vector2.ZERO)
            var tx:float=x+12
            var tw:float=438
            draw_rect(Rect2(tx,437,tw,5),Color("#405565"))
            draw_rect(Rect2(tx,437,tw*t/DURATION,5),Color("#78b7d3"))
            for k in clips[i].keys:
                var px:float=tx+tw*float(k.t)/DURATION
                draw_line(Vector2(px,434),Vector2(px,447),Color("#d6c6a1"),1)
            for j in range(hits.size()):
                var hx:float=tx+tw*float(hits[j])/DURATION
                draw_line(Vector2(hx,430),Vector2(hx,449),Color("#f0a65c"),2)
                draw_string(ThemeDB.fallback_font,Vector2(hx-4,464),str(j+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#f0a65c"))
            var lx:float=tx+tw*float(LAND)/float(END)
            draw_line(Vector2(lx,429),Vector2(lx,451),Color("#7ad6b1"),2)
            draw_string(ThemeDB.fallback_font,Vector2(lx-10,482),"LAND",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#7ad6b1"))
        var phase:String="ANTICIPATION" if t*120<LAUNCH else ("FLIGHT" if t*120<LAND else ("ABSORB" if t*120<126 else "RECOVER"))
        draw_string(ThemeDB.fallback_font,Vector2(16,521),"%s  |  %.0f ms  |  same flight, timing and landing; different attack poses"%[phase,t*1000],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#b4c2cc"))
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

func _world_pose(rig,hip_deg:float,chest_deg:float,segments:Array)->Dictionary:
    var hip:float=deg_to_rad(hip_deg)
    var chest:float=deg_to_rad(chest_deg)
    var a:Dictionary={"hips":hip_deg,"chest":chest_deg-hip_deg,"head":-chest_deg*.45}
    for i in range(4):
        var c:Array=CHAINS[i]
        var off1:Vector2=rig.joints[rig.ids[c[1]]].offset
        var off2:Vector2=rig.joints[rig.ids[c[2]]].offset
        var upper:float=deg_to_rad(float(segments[i*2]))-off1.angle()
        var lower:float=deg_to_rad(float(segments[i*2+1]))-off2.angle()
        var parent:float=hip if i>=2 else chest
        a[c[0]]=rad_to_deg(wrapf(upper-parent,-PI,PI))
        a[c[1]]=rad_to_deg(wrapf(lower-upper,-PI,PI))
    return a
func _pose_angles(rig,idx:int,tick:int)->Dictionary:
    match idx:
        -2: return _world_pose(rig,14,22,[100,18,125,35,55,125,125,55])
        -3: return _world_pose(rig,8,12,[135,35,140,45,82,100,100,80])
        # New second strike: far arm rising diagonally; near arm guards the body.
        -4: return _world_pose(rig,-12,-23,[115,5,145,85,55,132,112,58])
        -5: return _world_pose(rig,8,19,[102,-8,-48,-35,50,140,125,72])
        # Airborne recovery: retract kick, extend both legs toward ground.
        -6: return _world_pose(rig,-5,0,[108,14,132,30,44,129,115,65])
        -7: return _world_pose(rig,8,11,[105,13,127,39,70,108,111,73])
        -8: return _world_pose(rig,10,16,[95,12,128,45,72,108,108,72])
        -9: return _world_pose(rig,17,27,[86,2,125,48,44,135,135,45])
        -10: return _world_pose(rig,9,14,[99,8,122,31,62,116,116,64])
        -11: return GUARD.duplicate(true)
        _: return _retarget(rig,idx,tick)
func _root_at(tick:float)->Vector2:
    if tick<LAUNCH:
        var y:float=lerpf(2.8,7.0,smoothstep(0.0,12.0,tick))
        if tick>12:y=lerpf(7.0,1.8,smoothstep(12.0,20.0,tick))
        return Vector2(0,y)
    if tick<=LAND:
        var u:float=clampf((tick-float(LAUNCH))/float(LAND-LAUNCH),0,1)
        return Vector2(TRAVEL*u,1.8-4.0*HEIGHT*u*(1.0-u))
    var v:float=clampf((tick-float(LAND))/12.0,0,1)
    var x:float=TRAVEL+3.0*(1.0-pow(1.0-v,2.0))
    var y:float=lerpf(1.8,7.5,smoothstep(106.0,114.0,tick))
    if tick>114:y=lerpf(7.5,2.8,smoothstep(114.0,140.0,tick))
    return Vector2(x,y)
func _plant(rig,p:Dictionary,targets:Dictionary)->Dictionary:
    # Analytic two-bone IK: fixed foot targets, fixed bone lengths, fixed knee bend direction.
    rig.evaluate(p)
    for side in ["near","far"]:
        var thigh:String="thigh_"+side
        var knee:String="knee_"+side
        var foot:String="foot_"+side
        var a:Vector2=rig.point(thigh)
        var target:Vector2=Vector2(targets[side])
        var d:Vector2=target-a
        var o1:Vector2=rig.joints[rig.ids[knee]].offset
        var o2:Vector2=rig.joints[rig.ids[foot]].offset
        var l1:float=o1.length()
        var l2:float=o2.length()
        var length:float=clampf(d.length(),.001,l1+l2-.001)
        var sign_bend:float=1.0 if side=="near" else -1.0
        var upper:float=d.angle()-sign_bend*acos(clampf((l1*l1+length*length-l2*l2)/(2.0*l1*length),-1,1))
        var end:Vector2=a+d.normalized()*length
        var mid:Vector2=a+Vector2.from_angle(upper)*l1
        var lower:float=(end-mid).angle()
        var wu:float=upper-o1.angle()
        var wl:float=lower-o2.angle()
        p.angles[thigh]=rad_to_deg(wrapf(wu-float(rig.rotations.hips),-PI,PI))
        p.angles[knee]=rad_to_deg(wrapf(wl-wu,-PI,PI))
        rig.evaluate(p)
    return p
func _sample_final(rig,clip:Dictionary,t:float,feet:Dictionary)->Dictionary:
    var tick:float=clampf(t*120.0,0,float(END))
    var p:Dictionary=CLIPS.sample(clip,t,false)
    var r:Vector2=_root_at(tick)
    p.root=[r.x,r.y]
    if tick<=LAUNCH:return _plant(rig,p,feet.start)
    if tick>=LAND:return _plant(rig,p,feet.end)
    rig.evaluate(p)
    # Contact safety for the airborne extremes only; no per-key root easing.
    p.root[1]-=maxf(0,maxf(rig.point("foot_near").y,rig.point("foot_far").y))
    return p
func _build()->Dictionary:
    var rig=RIG.humanoid()
    rig.evaluate(CLIPS.pose(GUARD))
    var feet:Dictionary={"start":{"near":Vector2(rig.point("foot_near").x,0),"far":Vector2(rig.point("foot_far").x,0)},"end":{"near":Vector2(TRAVEL+9,0),"far":Vector2(TRAVEL-7,0)}}
    var directed:Dictionary={"duration":DURATION,"loop":false,"keys":[],"events":[],"easing":"smooth"}
    var staged:Dictionary=directed.duplicate(true)
    var hits:Array=[]
    for beat in BEATS:
        var tick:int=int(beat[0])
        var t:float=float(tick)/120.0
        var angles:Dictionary=_pose_angles(rig,int(beat[1]),tick)
        var p:Dictionary=CLIPS.pose(angles)
        if tick==LAUNCH or tick==LAND:
            var r:Vector2=_root_at(float(tick))
            p.root=[r.x,r.y]
            p=_plant(rig,p,feet.start if tick==LAUNCH else feet.end)
            p.root=[0,0]
        var k:Dictionary={"t":t,"pose":p,"easing":"snap" if tick>LAUNCH and tick<LAND else "smooth"}
        directed.keys.append(k)
        var ks:Dictionary=k.duplicate(true)
        if STAGED.has(tick):
            var data:Array=STAGED[tick]
            ks.pose=CLIPS.pose(_world_pose(rig,float(data[0]),float(data[1]),data[2]))
        staged.keys.append(ks)
        var anchor:String=String(beat[2])
        if not anchor.is_empty():
            hits.append(t)
            var ev:Dictionary={"t":t,"kind":"strike","anchor":anchor}
            for clip in [directed,staged]:clip.events.append(ev.duplicate(true))
    return {"clips":[directed,staged],"feet":feet,"hits":hits}
func _run()->void:
    root.size=Vector2i(960,540)
    var board=Board.new()
    var bundle:Dictionary=_build()
    board.clips=bundle.clips
    board.feet=bundle.feet
    board.hits=bundle.hits
    root.add_child(board)
    await process_frame
    var out:String=ProjectSettings.globalize_path("res://../reports/limited")
    DirAccess.make_dir_recursive_absolute(out)
    var rig=RIG.humanoid()
    var baked:Array=[]
    var max_plant_error:float=0
    for clip in bundle.clips:
        var export_clip:Dictionary={"duration":DURATION,"loop":false,"keys":[],"events":clip.events,"easing":"linear"}
        for tick in range(END+1):
            var t:float=float(tick)/120.0
            var p:Dictionary=_sample_final(rig,clip,t,bundle.feet)
            rig.evaluate(p)
            for pt in rig.points.values():
                if not Vector2(pt).is_finite():
                    push_error("Nonfinite pose");quit(1);return
            if tick<=LAUNCH or tick>=LAND:
                var targets:Dictionary=bundle.feet.start if tick<=LAUNCH else bundle.feet.end
                for side in ["near","far"]:
                    max_plant_error=maxf(max_plant_error,rig.point("foot_"+side).distance_to(Vector2(targets[side])))
            export_clip.keys.append({"t":t,"pose":p})
        baked.append(export_clip)
    var d:Dictionary=bundle.clips[0]
    var f:Dictionary=bundle.clips[1]
    if d.keys.size()!=f.keys.size() or d.events!=f.events:
        push_error("Cadence mismatch");quit(1);return
    for i in range(d.keys.size()):
        var a:Dictionary=d.keys[i]
        var b:Dictionary=f.keys[i]
        if a.t!=b.t or a.easing!=b.easing:
            push_error("Exposure mismatch");quit(1);return
        if not STAGED.has(roundi(float(a.t)*120.0)) and a.pose!=b.pose:
            push_error("Non-choreography pose changed");quit(1);return
    # Attack direction is validated on the actual skeleton, not inferred from labels.
    var reach:Array=[]
    for ev in f.events:
        var p:Dictionary=_sample_final(rig,f,float(ev.t),bundle.feet)
        rig.evaluate(p)
        var anchor:String=String(ev.anchor)
        var tip:Vector2=rig.point(anchor)
        var origin:Vector2=rig.point(("thigh_" if anchor.begins_with("foot") else "shoulder_")+anchor.get_slice("_",1))
        var delta:Vector2=tip-origin
        reach.append(delta.x)
        if delta.x<17.0:
            push_error("Staged strike fails forward extension: "+anchor+" "+str(delta));quit(1);return
    if bundle.hits.size()!=3 or max_plant_error>1.5:
        push_error("Contact/impact error: "+str(max_plant_error));quit(1);return
    var data=FileAccess.open(out.path_join("clips.json"),FileAccess.WRITE)
    data.store_string(JSON.stringify({"labels":["D","F"],"authored":bundle.clips,"baked":baked,"max_plant_error":max_plant_error,"staged_strike_reach_px":reach},"  ",true,true))
    data.close()
    for i in range(FRAME_COUNT):
        board.t=clampf(float(i-7)/60.0,0,DURATION)
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(out.path_join("frame_%03d.png"%i))!=OK:
            push_error("PNG save failed");quit(1);return
    print("LAB 0.42 native OK: %d frames; D/F %d/%d keys; planted error %.4f; forward reaches "%[FRAME_COUNT,d.keys.size(),f.keys.size(),max_plant_error],reach)
    quit()
