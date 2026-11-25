extends RefCounted
## Runtime entry contract. No dependency on any editor or lab.
const ANATOMY=preload("res://addons/creature/anatomy.gd")
const PHYS=preload("res://addons/creature/physical_creature.gd")
const SPECIAL=preload("res://addons/creature/physical_ability.gd")
const ABILITY=preload("res://addons/creature/ability.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const FX=preload("res://addons/pixelfx/composer/preset.gd")
static func valid(e:Variant)->bool:
    if not e is Dictionary or e.get("schema")!=1 or not e.get("name") is String or not e.get("payload") is Dictionary:return false
    var p:Dictionary=e.payload
    match e.get("kind"):
        "creature":return ANATOMY.valid(p)
        "vfx":return FX.valid(p)
        "ability":return SPECIAL.valid(p) or ABILITY.valid(p)
        "animation":
            if not p.get("slot") in CLIPS.NAMES or not p.get("clip") is Dictionary:return false
            var bank:Dictionary=CLIPS.defaults()
            bank[p.slot]=p.clip
            return CLIPS.valid(bank)
    return false
static func read(path:String)->Dictionary:
    var file:=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>8*1024*1024:return {}
    var e:Variant=JSON.parse_string(file.get_as_text())
    return e if valid(e) else {}
static func create_creature(e:Dictionary,at:Vector2,obstacles:Array[Rect2]):
    if not valid(e) or e.kind!="creature":return null
    return PHYS.new(at,obstacles,2,1,true,1.0,e.payload)
static func attach_ability(e:Dictionary,creature)->bool:
    return valid(e) and e.kind=="ability" and SPECIAL.compatible(e.payload,creature) and creature.special.configure(e.payload)
static func animation_bank(e:Dictionary)->Dictionary:
    if not valid(e) or e.kind!="animation":return {}
    var bank:Dictionary=CLIPS.defaults()
    bank[e.payload.slot]=e.payload.clip.duplicate(true)
    return bank
static func compile_ability(e:Dictionary)->Dictionary:
    if not valid(e) or e.kind!="ability":return {}
    return ABILITY.compile(e.payload) if ABILITY.valid(e.payload) else {}
