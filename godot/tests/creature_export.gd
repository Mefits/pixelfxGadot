extends SceneTree
const CAT=preload("res://addons/creature/catalog.gd")
const EXP=preload("res://addons/creature/kit_export.gd")
const API=preload("res://addons/creature/kit_api.gd")
var failures:int=0
func _initialize()->void:call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
func _run()->void:
    check(EXP.available(),"Runtime ZIP bundled")
    var selected:Array=["fx_5","anim_strike","ability_electric","creature_tentacled","physical_grab"]
    var folder:String=OS.get_environment("CREATURE_EXPORT_TEST_DIR")
    if folder.is_empty():folder="user://export_test"
    DirAccess.make_dir_recursive_absolute(folder)
    for e in CAT.builtins():
        check(API.valid(e),"Runtime schema "+e.id)
        if not e.id in selected:continue
        var path:String=folder.path_join(e.id+".zip")
        if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
        check(EXP.export_entry(e,path)==OK,"Export "+e.id)
        check(EXP.export_entry(e,path)==ERR_ALREADY_EXISTS,"No overwrite "+e.id)
        var z:=ZIPReader.new()
        if z.open(path)!=OK:check(false,"Open ZIP "+e.id);continue
        var names:PackedStringArray=z.get_files()
        check(names.has("project.godot") and names.has("content/template.json") and names.has("example/demo.gd"),"Complete standalone project")
        for n in names:check(not n.begins_with("lab/"),"No editor dependencies")
        var value:Variant=JSON.parse_string(z.read_file("content/template.json").get_string_from_utf8())
        check(API.valid(value) and value.id==e.id,"Exported payload valid")
        z.close()
    check(EXP.export_entry({},folder.path_join("invalid.zip"))==ERR_INVALID_PARAMETER,"Reject invalid data")
    print("Export tests failures: ",failures)
    quit(0 if failures==0 else 1)
