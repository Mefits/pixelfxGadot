extends RefCounted
## Exports source files from a prebuilt, editor-independent runtime ZIP.
## The archive is bundled even in a desktop PCK; compiled GDScript need not
## be decompiled. Never write into the user's game project automatically.
const API=preload("res://addons/creature/kit_api.gd")
const RUNTIME="res://portable/runtime.zip"
const MAX_BYTES=16*1024*1024
static func available()->bool:
    return FileAccess.file_exists(RUNTIME)
static func safe_path(path:String)->bool:
    if path.is_empty() or path.begins_with("/") or path.contains("\\") or path.contains(":"):return false
    for part in path.split("/"):
        if part.is_empty() or part=="." or part=="..":return false
    return path.begins_with("addons/") or path.begins_with("example/") or path in ["project.godot","README.md","LICENSE-PixelFX.txt","LICENSE-godot-cpp.txt","LICENSE-QuickJS-NG.txt"]
static func _write(pack:ZIPPacker,path:String,bytes:PackedByteArray)->bool:
    if pack.start_file(path)!=OK:return false
    var ok:bool=pack.write_file(bytes)==OK
    return pack.close_file()==OK and ok
static func export_entry(e:Dictionary,path:String)->Error:
    if not API.valid(e) or not path.to_lower().ends_with(".zip"):return ERR_INVALID_PARAMETER
    if FileAccess.file_exists(path):return ERR_ALREADY_EXISTS
    if not available():return ERR_FILE_NOT_FOUND
    var reader:=ZIPReader.new()
    var err:Error=reader.open(RUNTIME)
    if err!=OK:return err
    var temporary:String=path+".partial_"+str(Time.get_ticks_usec())
    var pack:=ZIPPacker.new()
    err=pack.open(temporary)
    if err!=OK:
        reader.close()
        return err
    var total:int=0
    var files:PackedStringArray=reader.get_files()
    for name in files:
        if not safe_path(name):
            err=ERR_INVALID_DATA
            break
        var bytes:PackedByteArray=reader.read_file(name)
        total+=bytes.size()
        if total>MAX_BYTES or not _write(pack,name,bytes):
            err=ERR_CANT_CREATE
            break
    reader.close()
    if err==OK:
        var data:Dictionary={"schema":1,"id":str(e.get("id","template")),"name":e.name,"kind":e.kind,"payload":e.payload.duplicate(true),"source":"export"}
        if not _write(pack,"content/template.json",JSON.stringify(data,"  ",true,true).to_utf8_buffer()):err=ERR_CANT_CREATE
    if err==OK:
        var manifest:Dictionary={"schema":1,"toolkit_version":"0.30","godot":"4.4.1","backend":"gdscript","entry":"content/template.json","kind":e.kind,"files":Array(files)}
        if not _write(pack,"content/manifest.json",JSON.stringify(manifest,"  ").to_utf8_buffer()):err=ERR_CANT_CREATE
    var closed:Error=pack.close()
    if err==OK:err=closed
    if err==OK:
        if FileAccess.file_exists(path):err=ERR_ALREADY_EXISTS
        else:err=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
    if err!=OK:DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
    return err
