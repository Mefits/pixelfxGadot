extends RefCounted
## Schema for reusable physical anatomy, independent of scene and skin.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const TYPES=["quadruped","biped","crawler","manylegs","tentacled"]
static func defaults()->Dictionary:
    return {"schema":1,"name":"Четвероногий","type":"quadruped","tail":2,"mass":1.0,"limbs":true,"leg_count":4,"reach":1.0,"trunk":sqrt(260.0),"speed":126.0,"jump":230.0,"tentacles":0,"tentacle_segments":3,"tentacle_length":8.0}
static func normalize(p:Dictionary)->Dictionary:
    var out:Dictionary=defaults()
    out.merge(p,true)
    return out
static func valid(p:Variant)->bool:
    if not p is Dictionary:return false
    if not P.num(p.get("tail"),0,12) or float(p.tail)!=floorf(float(p.tail)) or not P.num(p.get("mass"),.5,3) or not p.get("limbs") is bool:return false
    var a:Dictionary=normalize(p)
    if a.schema!=1 or not a.name is String or a.name.strip_edges().is_empty() or not a.type in TYPES:return false
    for spec in [["leg_count",0,8],["tentacles",0,4],["tentacle_segments",2,6]]:
        if not P.num(a[spec[0]],spec[1],spec[2]) or floorf(float(a[spec[0]]))!=float(a[spec[0]]):return false
    if int(a.leg_count)%2!=0 or (a.limbs and int(a.leg_count)<2):return false
    if a.type=="biped" and int(a.leg_count)!=2:return false
    for spec in [["reach",.75,1.5],["trunk",12,24],["speed",35,180],["jump",80,280],["tentacle_length",5,12]]:
        if not P.num(a[spec[0]],spec[1],spec[2]):return false
    return true
static func templates()->Array:
    var quad:Dictionary=defaults()
    var biped:Dictionary=defaults()
    biped.merge({"name":"Двуногий протогуманоид","type":"biped","tail":0,"leg_count":2,"trunk":20.0,"speed":110.0,"jump":215.0},true)
    var worm:Dictionary=defaults()
    worm.merge({"name":"Червеобразный организм","type":"crawler","tail":10,"limbs":false,"leg_count":0,"mass":.8,"speed":75.0,"jump":90.0},true)
    var multi:Dictionary=defaults()
    multi.merge({"name":"Восьминогое существо","type":"manylegs","tail":3,"leg_count":8,"reach":1.2,"trunk":20.0,"mass":1.6,"speed":100.0},true)
    var tentacle:Dictionary=defaults()
    tentacle.merge({"name":"Организм со щупальцами","type":"tentacled","tail":3,"leg_count":4,"tentacles":2,"tentacle_segments":4,"tentacle_length":8.0,"mass":1.25,"speed":100.0},true)
    return [quad,biped,worm,multi,tentacle]
