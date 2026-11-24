extends RefCounted
## Store validated preset snapshots per animation/combat cue; no disk access at cast time.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const PATH="user://creature_vfx_bindings.json"
const ROLES=["charge","cast","strike","cross","heavy","kick","air_strike","impact","block"]
static func valid(data: Variant) -> bool:
    if not data is Dictionary:return false
    for role in data:
        if not role in ROLES or not P.valid(data[role]):return false
    return true
static func load_bank(path: String=PATH) -> Dictionary:
    if not FileAccess.file_exists(path):return {}
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
    return data if valid(data) else {}
static func save_bank(bank: Dictionary,path: String=PATH) -> bool:
    if not valid(bank):return false
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify(bank,"  "))
    return true
