extends SceneTree
func _initialize():call_deferred("run")
func run():
    var editor=load("res://lab/authoring/editor.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    for child in editor.get_children():
        if child is Button and child.text=="Хореография":child.pressed.emit()
    var panel=editor.get_node("Choreography")
    panel.key_picker.select(4)
    panel.field.select(1)
    panel.select_key()
    panel.value_edit.value=9.
    panel.write_key()
    panel.frame.value=30
    panel.move_marker()
    var d=panel.doc.duplicate(true)
    d.id="workshop_choreo_test"
    panel.source.text=JSON.stringify(d)
    panel.save_doc()
    panel.reload_doc()
    var ok:bool=panel.doc.id==d.id and panel.doc.keys[4].root[0]==9. and panel.picture.texture!=null and roundi(panel.doc.events[0].t*60)==30
    print("CHOREO_WORKSHOP ",ok)
    quit(0 if ok else 1)
