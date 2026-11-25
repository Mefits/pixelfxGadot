extends SceneTree
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const SKIN=preload("res://addons/creature/skin.gd")
const NAMES=["hips","chest","head","shoulder_near","elbow_near","shoulder_far","elbow_far","thigh_near","knee_near","thigh_far","knee_far"]
const BEATS=[
    [0,[0,0,0,-44,-70,24,-90,-23,30,18,-27]],
    [12,[-5,-9,6,-20,-105,12,-100,-27,50,20,-44]],
    [24,[-12,-11,9,48,-111,-12,-107,-38,71,12,-35]],
    [32,[-10,-14,12,55,-110,-16,-102,-36,69,17,-37]],
    [38,[8,5,-5,-48,-42,18,-105,-25,44,20,-32]],
    [40,[16,9,-12,-96,-10,25,-98,-27,33,14,-20]],
    [48,[16,9,-12,-96,-10,25,-98,-27,33,14,-20]],
    [56,[9,4,-7,-59,-62,19,-103,-25,45,15,-34]],
    [72,[0,0,0,-44,-70,24,-90,-23,30,18,-27]],
    [96,[0,0,0,-44,-70,24,-90,-23,30,18,-27]]
]
class Board extends Node2D:
    var rig=RIG.humanoid()
    var clips:Array=[]
    var t:float=0.0
    const LABELS=["A  Smooth","B  15 poses/s","D  Directed timing","E  Reduced keys"]
    const SUBS=["Continuous interpolation","Fixed 8-tick exposure","Authored exposure","7 keys / no interpolation"]
    func _draw()->void:
        draw_rect(Rect2(0,0,960,540),Color("#14212b"))
        draw_string(ThemeDB.fallback_font,Vector2(16,27),"LAB 0.39  /  GODOT NATIVE CADENCE STUDY",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("#e6edf3"))
        for i in range(4):
            var x:float=12+float(i%2)*474.0
            var y:float=42+float(i/2)*0.0
            y=42+float(i>>1)*242.0
            draw_rect(Rect2(x,y,462,234),Color("#213542"))
            draw_string(ThemeDB.fallback_font,Vector2(x+13,y+22),LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#e6edf3"))
            draw_string(ThemeDB.fallback_font,Vector2(x+13,y+40),SUBS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#aebec9"))
            var floor_y:float=y+209
            draw_line(Vector2(x+15,floor_y),Vector2(x+447,floor_y),Color("#83988f"),1.0)
            rig.evaluate(CLIPS.sample(clips[i],t,false))
            draw_set_transform(Vector2(x+225,floor_y),0,Vector2(3.0,3.0))
            SKIN.draw_body(self,rig,Vector2.ZERO,1,Color("#5aafdc"),false)
            draw_set_transform(Vector2.ZERO)
            draw_rect(Rect2(x+15,y+221,432,4),Color("#405565"))
            draw_rect(Rect2(x+15,y+221,432*t/.8,4),Color("#78b7d3"))
            for k in clips[i].keys:
                var px:float=x+15+432*float(k.t)/.8
                draw_line(Vector2(px,y+218),Vector2(px,y+229),Color("#d6c6a1"),1.0)
        draw_string(ThemeDB.fallback_font,Vector2(16,535),"Native rig.gd + skin.gd + clips.gd  |  120 Hz authoring; 60 Hz capture  |  %.0f ms"%(t*1000),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#b4c2cc"))
func _initialize()->void:
    call_deferred("_run")
func _build()->Array:
    var rig=RIG.humanoid()
    var base:Dictionary={"duration":.8,"loop":false,"keys":[],"events":[{"t":40.0/120.0,"kind":"strike","anchor":"hand_near"}],"easing":"smooth"}
    for beat in BEATS:
        var angles:Dictionary={}
        for i in range(NAMES.size()):angles[NAMES[i]]=beat[1][i]
        var p:Dictionary=CLIPS.pose(angles)
        rig.evaluate(p)
        p.root[1]=-maxf(rig.point("foot_near").y,rig.point("foot_far").y)
        base.keys.append({"t":float(beat[0])/120.0,"pose":p,"easing":"smooth"})
    var regular:Dictionary=base.duplicate(true)
    regular.keys=[]
    for i in range(0,97,8):
        regular.keys.append({"t":float(i)/120.0,"pose":CLIPS.sample(base,float(i)/120.0,false),"easing":"snap"})
    var directed:Dictionary=base.duplicate(true)
    for k in directed.keys:k.easing="snap"
    var reduced:Dictionary=directed.duplicate(true)
    reduced.keys=[]
    # Omit load subdivision (24), swing breakdown (38) and duplicate hold key (48).
    for i in [0,1,3,5,7,8,9]:reduced.keys.append(directed.keys[i].duplicate(true))
    return [base,regular,directed,reduced]
func _run()->void:
    root.size=Vector2i(960,540)
    var board=Board.new()
    board.clips=_build()
    root.add_child(board)
    await process_frame
    var out:String=ProjectSettings.globalize_path("res://../reports/limited")
    DirAccess.make_dir_recursive_absolute(out)
    # Check that the snap holds preceding pose exactly until the next key.
    if CLIPS.sample(board.clips[2],.15,false)!=board.clips[2].keys[1].pose:
        push_error("Snap sampler does not hold");quit(1);return
    for c in board.clips:
        if CLIPS.sample(c,40.0/120.0,false)!=board.clips[0].keys[5].pose:
            push_error("Impact pose drift");quit(1);return
    var data=FileAccess.open(out.path_join("clips.json"),FileAccess.WRITE)
    data.store_string(JSON.stringify(board.clips,"  ",true,true))
    data.close()
    for i in range(78):
        board.t=clampf(float(i-12)/60.0,0,.8)
        board.queue_redraw()
        await process_frame
        await RenderingServer.frame_post_draw
        if root.get_texture().get_image().save_png(out.path_join("frame_%03d.png"%i))!=OK:
            push_error("PNG save failed");quit(1);return
    print("LAB native cadence OK: 78 frames; keys 10 / 13 / 10 / 7; equal strike pose")
    quit()
