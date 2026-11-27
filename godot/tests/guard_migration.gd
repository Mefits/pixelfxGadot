extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/walk_motion.gd")
func _initialize():call_deferred("run")
func run():
    # CI uses an isolated Godot user directory. Never overwrite a real file.
    for id in ["walk_idle","walk_breathe"]:
        if FileAccess.file_exists(Asset.FOLDER+id+".json"):
            push_error("migration test requires clean user directory")
            quit(1)
            return
    var old:Dictionary=Motion.default_doc("walk_idle")
    old.erase("guard_revision")
    var static_idle:Dictionary=Motion.breathing_doc(old)
    static_idle.erase("guard_revision")
    for k in static_idle.keys:
        k.angles=old.keys[0].angles.duplicate(true)
        k.root=old.keys[0].root.duplicate()
    if Asset.persist(old)!=OK or Asset.persist(static_idle)!=OK:
        push_error("migration fixture")
        quit(1)
        return
    var before_idle:PackedByteArray=FileAccess.get_file_as_bytes(Asset.FOLDER+"walk_breathe.json")
    var before_stance:PackedByteArray=FileAccess.get_file_as_bytes(Asset.FOLDER+"walk_idle.json")
    var stance:Dictionary=Motion.document("walk_idle")
    var idle:Dictionary=Motion.document("walk_breathe")
    var folder:String="user://motion_authoring_backup/"
    var ok:bool=stance.guard_revision==Motion.GUARD_REVISION and idle.guard_revision==Motion.GUARD_REVISION
    ok=ok and FileAccess.get_file_as_bytes(folder+"walk_breathe_before_guard_v2.json")==before_idle
    ok=ok and FileAccess.get_file_as_bytes(folder+"walk_idle_before_guard_v2.json")==before_stance
    ok=ok and idle.keys[2].root!=idle.keys[0].root
    # A new edited idle remains bound and is not migrated again.
    idle.keys[1].angles.chest+=1.
    ok=ok and Asset.persist(idle)==OK
    ok=ok and is_equal_approx(Motion.document("walk_breathe").keys[1].angles.chest,idle.keys[1].angles.chest)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Asset.FOLDER+"walk_breathe.json"))
    if ok:print("GUARD_MIGRATION_OK")
    else:push_error("guard migration failed")
    quit(0 if ok else 1)
