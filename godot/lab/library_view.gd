extends RefCounted
## Independent launcher state; never modifies template payloads.
const PATH="user://creature_library_view.cfg"
const LIMIT=20
var favorites:Array[String]=[]
var recent:Array[String]=[]
func load_state()->void:
    var cfg:=ConfigFile.new()
    if cfg.load(PATH)!=OK:return
    favorites.assign(_strings(cfg.get_value("library","favorites",[]),200))
    recent.assign(_strings(cfg.get_value("library","recent",[]),LIMIT))
func _strings(value:Variant,limit:int)->Array[String]:
    var out:Array[String]=[]
    if value is Array or value is PackedStringArray:
        for id in value:
            if id is String and not id.is_empty() and id.length()<=240 and not id in out:
                out.append(id)
                if out.size()>=limit:break
    return out
func save_state()->void:
    var cfg:=ConfigFile.new()
    cfg.set_value("library","favorites",favorites)
    cfg.set_value("library","recent",recent)
    cfg.save(PATH)
func toggle(id:String)->void:
    if id in favorites:favorites.erase(id)
    elif favorites.size()<200:favorites.append(id)
    save_state()
func opened(id:String)->void:
    recent.erase(id)
    recent.push_front(id)
    if recent.size()>LIMIT:recent.resize(LIMIT)
    save_state()
func remove(id:String)->void:
    recent.erase(id)
    favorites.erase(id)
    save_state()
func includes(e:Dictionary,scope:int)->bool:
    match scope:
        1:return e.source!="builtin"
        2:return e.id in favorites
        3:return e.id in recent
        4:return e.source=="trash"
    return true
