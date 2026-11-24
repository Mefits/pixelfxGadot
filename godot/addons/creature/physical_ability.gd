extends RefCounted
## Independent physical ability profiles; no scene or input dependencies.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const TYPES=["grab","leap","claw","bolt","grow","acid"]
static func templates()->Array:
    return [
        {"schema":1,"engine":"physical","type":"grab","name":"Захват щупальцем","duration":1.4,"reach":48.0,"power":90.0,"damage":0,"cooldown":.45},
        {"schema":1,"engine":"physical","type":"leap","name":"Прыжок на противника","duration":.85,"reach":22.0,"power":210.0,"damage":24,"cooldown":.55},
        {"schema":1,"engine":"physical","type":"claw","name":"Удар когтями","duration":.65,"reach":28.0,"power":100.0,"damage":20,"cooldown":.25},
        {"schema":1,"engine":"physical","type":"bolt","name":"Энергетический выстрел","duration":1.2,"reach":150.0,"power":170.0,"damage":22,"cooldown":.35},
        {"schema":1,"engine":"physical","type":"grow","name":"Рост хвоста","duration":.25,"reach":20.0,"power":100.0,"damage":0,"cooldown":.35},
        {"schema":1,"engine":"physical","type":"acid","name":"Кислотный плевок","duration":1.2,"reach":120.0,"power":125.0,"damage":15,"cooldown":.5}]
static func valid(p:Variant)->bool:
    if not p is Dictionary or p.get("schema")!=1 or p.get("engine")!="physical" or not p.get("type") in TYPES or not p.get("name") is String or p.name.strip_edges().is_empty():return false
    for spec in [["duration",.2,3],["reach",8,240],["power",20,280],["damage",0,60],["cooldown",0,3]]:
        if not P.num(p.get(spec[0]),spec[1],spec[2]):return false
    return floorf(float(p.damage))==float(p.damage)
static func compatible(p:Dictionary,c)->bool:
    if not valid(p):return false
    match p.type:
        "grab":return not c.branches.is_empty()
        "claw":return c.limbs.enabled and not c.upright and c.limbs.legs.size()>=2
        "grow":return c.tail_count<12
        "leap":return c.limbs.enabled
    return true
