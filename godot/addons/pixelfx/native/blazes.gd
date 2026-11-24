extends RefCounted
## Original PixelFX core/sim.js Blazes, MIT Patch/Hugo Duprez.
const P=preload("res://addons/pixelfx/native/particles.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
var ps
var list: Array[Dictionary]=[]
var hot: Array=PAL.fit(P.HOT_HEX,4)

func _init(particles) -> void:
    ps=particles

func add(x: float,y: float,life: float,power: float) -> void:
    list.append({"x":x,"y":y,"life":life,"max":life,"acc":ps.rng.next(),"power":power})

func count() -> int:
    return list.size()

func update(dt: float) -> void:
    var r=ps.rng
    for i in range(list.size()-1,-1,-1):
        var b: Dictionary=list[i]
        b["life"]-=dt
        if b["life"]<=0:
            list.remove_at(i)
            continue
        var k: float=b["life"]/b["max"]
        var intensity: float=b["power"]*(1.0 if k>.7 else .35+(k/.7)*.65)
        b["acc"]+=dt*(6+16*intensity)
        while b["acc"]>1:
            var s: float=r.between(1.2,2.8)*intensity
            ps.spawn(P.FIRE,b["x"]+r.between(-1.5,1.5),b["y"]-s*.6,r.between(-6,6),r.between(-30,-12),r.between(.28,.6),0,s,0,P.BACK|(P.SMOKES if r.chance(.3) else 0))
            if r.chance(.06):
                ps.spawn(P.EMBER,b["x"],b["y"]-1.5,r.between(-15,15),r.between(-45,-15),r.between(.6,1.4),hot[2],1,0,P.BACK)
            b["acc"]-=1

func draw_back(p) -> void:
    for b in list:
        var k: float=b["life"]/b["max"]
        p.px(b["x"],b["y"],(hot[1] if sin(b["life"]*31+b["x"])>0 else hot[2]) if k>.4 else hot[3])
        p.glow(b["x"],b["y"],6+5*k*b["power"],hot[2],.3*k*b["power"])
