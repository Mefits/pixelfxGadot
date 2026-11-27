extends SceneTree
## Run with an isolated XDG_DATA_HOME. Persist a uniquely named test copy.
const Scene=preload("res://lab/authoring/editor.tscn")
const Asset=preload("res://lab/authoring/asset.gd")
var rows:Array=[]
var failed:=false
func verify(v:bool,s:String):
    if not v:
        failed=true
        push_error(s)
func _initialize():call_deferred("run")
func pair(a,b,folder:String,stage:String):
    var n:=rows.size()
    for lane in [a,b]:
        var name:String=("a" if lane==a else "b")+("%04d.png"%n)
        verify(lane.last_image.save_png(folder.path_join(name))==OK,"write")
    var entry={"stage":stage,"tick":b.frame,"travel":[a.player.gait.travel,b.player.gait.travel]}
    if stage=="DRAG":
        var g:Dictionary=b.document.goals[b.selected]
        entry.target=g.xy
        var hand:Vector2=b.at_joint(g.joint)
        entry.actual=[hand.x,hand.y]
    rows.append(entry)

func run():
    var folder:String=OS.get_cmdline_user_args()[0]
    var left=Scene.instantiate()
    var right=Scene.instantiate()
    root.add_child(left)
    root.add_child(right)
    if left.last_image==null:
        push_error("Native body raster required")
        quit(1)
        return
    for id in Asset.IDS:
        left.open_motion(id)
        right.open_motion(id)
        right.seek_accent()
        left.seek(right.frame)
        var pos:Vector2=right.at_joint("hand_near")
        if id!="feint":
            right.duplicate_motion()
            var copy:String=right.document.id
            right.seek(left.frame)
            var down:=InputEventMouseButton.new()
            down.button_index=MOUSE_BUTTON_LEFT
            down.pressed=true
            down.position=right.ORIGIN+pos*right.ZOOM
            right._unhandled_input(down)
            for j in range(1,19):
                var event:=InputEventMouseMotion.new()
                event.position=down.position+Vector2(-3.,-7.)*right.ZOOM*j/18.
                right._unhandled_input(event)
                verify(right.selected>=0,"mouse selected")
                if right.selected<0:
                    quit(1)
                    return
                pair(left,right,folder,"DRAG")
            down.pressed=false
            right._unhandled_input(down)
            var corrected:Vector2=right.at_joint("hand_near")
            verify(corrected.distance_to(pos)>2.,"visible edit")
            var expected:PackedByteArray=right.player.save()
            right.save_file()
            right.undo()
            verify(right.document.goals.is_empty(),"gesture undo")
            right.open_motion(copy)
            right.seek(left.frame)
            verify(expected==right.player.save(),"reload and replay exact")
            DirAccess.remove_absolute(Asset.FOLDER+copy+".json")
        for t in range(left.end_frame()+1):
            left.simulate(t)
            right.simulate(t)
            pair(left,right,folder,id)
    var file:=FileAccess.open(folder.path_join("rows.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify(rows))
    print("CAPTURE frames ",rows.size())
    quit(1 if failed else 0)
