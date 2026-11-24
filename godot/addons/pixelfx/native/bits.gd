extends RefCounted
## Direct reference port of the upstream Bits class (src/core/sim.js).
## Original MIT: Patch, Hugo Duprez, 2026.
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const SHARD: int=0
const CHUNK: int=1
const DRIP: int=2
const WHITE: int=0xffffffff
const GRAVITY: float=950.0
const DEFAULT_RAMP=["#1c2030","#3a4a66","#6e86a8","#a8c0dc","#e8f2ff"]
var list: Array[Dictionary]=[]
var ground: Callable
var capacity: int=512

func _init(ground_fn: Callable=Callable()) -> void:
    ground=ground_fn

func add(spec: Dictionary) -> bool:
    if list.size()>=capacity or float(spec.get("life",1.0))<=0.0:
        return false
    var life: float=spec.get("life",1.0)
    var b: Dictionary={"kind":SHARD,"vx":0.0,"vy":0.0,"a":0.0,"va":0.0,"s":1.0,"c":WHITE,"g":1.0,"drag":0.0,"bounce":0.0,"rest":false}
    b.merge(spec,true)
    b["life"]=life
    b["max"]=life
    if not b.has("x") or not b.has("y"):
        return false
    var ramp: Array=b.get("ramp",DEFAULT_RAMP)
    b["ramp_colors"]=PAL.fit(ramp,ramp.size())
    list.append(b)
    return true

func update(dt: float) -> void:
    for i in range(list.size()-1,-1,-1):
        var b: Dictionary=list[i]
        b["life"]-=dt
        if b["life"]<=0.0:
            list.remove_at(i)
            continue
        if b["rest"]:
            continue
        b["vy"]+=GRAVITY*b["g"]*dt
        b["vx"]-=b["vx"]*b["drag"]*dt
        b["vy"]-=b["vy"]*b["drag"]*dt
        b["x"]+=b["vx"]*dt
        b["y"]+=b["vy"]*dt
        b["a"]+=b["va"]*dt
        var floor_y: float=float(ground.call(b["x"])) if ground.is_valid() else INF
        var speed: float=b["vy"]
        if b["g"]<=0.0 or b["y"]<floor_y or speed<=0.0:
            continue
        b["y"]=floor_y-0.01
        if int(b["kind"])==DRIP:
            b["life"]=0.0
        elif b["bounce"]>0.0 and speed>70.0:
            b["vy"]=-speed*b["bounce"]
            b["vx"]*=0.7
            b["va"]*=0.6
        else:
            b["rest"]=true
            b["vx"]=0.0
            b["vy"]=0.0

func draw(p) -> void:
    for b in list:
        var a: float=minf(1.0,b["life"]/0.4)
        var ca: float=cos(b["a"])
        var sa: float=sin(b["a"])
        var s: float=b["s"]
        var col: int=b["c"]
        if int(b["kind"])==SHARD:
            var d: float=-s/2.0
            while d<=s/2.0:
                p.dot(b["x"]+ca*d,b["y"]+sa*d,WHITE if d>s/2.0-0.6 else col,a)
                d+=0.5
        elif int(b["kind"])==DRIP:
            p.dot(b["x"],b["y"],col,a)
            p.dot(b["x"],b["y"]-1.0,col,a*0.5)
        else:
            var ramp: Array=b["ramp_colors"]
            var n: int=ramp.size()
            var x: int=int(floor(b["x"]+0.5))
            var y: int=int(floor(b["y"]+0.5))
            var r: int=int(ceil(s))+1
            for py in range(-r,r+1):
                for px in range(-r,r+1):
                    var u: float=(px+0.5)*ca+(py+0.5)*sa
                    var v: float=-(px+0.5)*sa+(py+0.5)*ca
                    var d: float=absf(u)/s+absf(v)/(s*0.62)
                    if d>1.3:
                        continue
                    var c: int=ramp[0] if d>1.0 else (ramp[n-1] if u<0.0 else ramp[n-2]) if v<0.0 else (ramp[n-3] if u<0.0 else ramp[maxi(1,n-4)])
                    p.dot(x+px,y+py,c,a)
