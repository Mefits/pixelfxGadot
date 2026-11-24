extends RefCounted
## Direct port of the Lights class in src/core/sim.js, MIT Patch/Hugo Duprez.
var list: Array[Dictionary]=[]
var capacity: int=64

func add(x: float,y: float,r: float,color: int,k: float,life: float) -> bool:
    if list.size()>=capacity or life<=0.0:
        return false
    list.append({"x":x,"y":y,"r":r,"color":color,"k":k,"life":life,"max":life})
    return true

func update(dt: float) -> void:
    for i in range(list.size()-1,-1,-1):
        list[i]["life"]-=dt
        if list[i]["life"]<=0.0:
            list.remove_at(i)

func draw(p) -> void:
    for l in list:
        var k: float=l["life"]/l["max"]
        p.glow(l["x"],l["y"],l["r"]*(0.55+0.45*k),l["color"],l["k"]*k*k)
