extends RefCounted
## Direct port of original lightning/electrified.js. MIT Patch/Hugo Duprez.
## The original status effect, independent from the authored 3D actor rig.
const M=preload("res://addons/pixelfx/native/math.gd")
const L=preload("res://addons/pixelfx/native/lightning.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const A=preload("res://addons/pixelfx/native/actor.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const MOTION=preload("res://addons/pixelfx/native/motion.gd")
const SIZE:=Vector2i(108,92)
const PIVOT:=Vector2i(54,76)
const JOLTS=[[3,1.0],[22,.7],[41,.9]]
const META={"duration":2.0,"loop":true,"actor":2,"options":{"palette":L.VOLT,"sparks":["#ffffff","#c8f8ff","#7ff3ff","#1ab8e6"],"seed":5}}
var lightning=L.new()
var batch=BATCH.new()
var c: Array
var sparks: Array
var actor: Dictionary
var edges: Array=[]
var seed_value: int

func _init(o: Dictionary={}) -> void:
    c=PAL.fit(o.get("palette",L.VOLT),8)
    var s: Array=o.get("sparks",META["options"]["sparks"])
    sparks=PAL.fit(s,s.size())
    seed_value=o.get("seed",5)
    set_actor(o.get("actor",A.stock(2)))

func set_actor(value: Dictionary) -> void:
    actor=value
    edges.clear()
    var m: Dictionary=actor["mask"]
    for y in range(int(m["h"])):
        for x in range(int(m["w"])):
            if _on(m,x,y) and (not _on(m,x-1,y) or not _on(m,x+1,y) or not _on(m,x,y-1) or not _on(m,x,y+1)):
                edges.append([actor["x"]+x+.5,actor["y"]+y+.5])

static func _on(m: Dictionary,x: int,y: int) -> bool:
    return x>=0 and y>=0 and x<int(m["w"]) and y<int(m["h"]) and bool(m["data"][y*int(m["w"])+x])

func enable_acceleration(enabled: bool=true) -> bool:
    var a: bool=lightning.enable_acceleration(enabled)
    var b: bool=batch.enable_acceleration(enabled)
    return a and b

static func _jolt(f: int) -> Dictionary:
    for q in JOLTS:
        if f>=q[0] and f<q[0]+3:
            return {"a":f-q[0],"k":q[1]}
    return {}

func draw_back(p,t: float) -> void:
    var f: int=int(floor(t*30+1e-6))%60
    var j: Dictionary=_jolt(f)
    var r=M.rng_for([seed_value,4,f])
    p.outline(actor["mask"],actor["x"],actor["y"],c[4] if not j.is_empty() else (c[2] if r.next()<.5 else c[1]))
    var d=batch.begin(p)
    d.glow(0,-18,30,c[3],.55*j["k"] if not j.is_empty() else .16+.1*r.next())
    d.glow(0,-2,22,c[4],.18)
    batch.finish()

func draw(p,t: float) -> void:
    if edges.is_empty():
        return
    var f: int=int(floor(t*30+1e-6))%60
    var j: Dictionary=_jolt(f)
    var d=batch.begin(p)
    if not j.is_empty():
        var lift: float=[1.1,.6,-.2][j["a"]]*j["k"]
        for y in range(int(actor["h"])):
            for x in range(int(actor["w"])):
                var col: int=actor["pixels"][y*int(actor["w"])+x]
                if col:
                    d.px(actor["x"]+x,actor["y"]+y,c[1+clampi(int(floor(.4+PAL.luma(col)*6+lift+.5)),0,6)])
        d.glow(0,-19,26,c[5],.5*j["k"]*(1-float(j["a"])/3))
    batch.finish()
    var r=M.rng_for([seed_value,7,f>>1])
    var n: int=2+(2 if not j.is_empty() else r.integer(0,1))
    for i in range(n):
        var a: Array=r.pick(edges)
        var ang: float=r.between(0,TAU)
        var dist: float=r.between(6,14)
        var b: Array=[a[0]+cos(ang)*dist,a[1]+sin(ang)*dist]
        for k in range(10):
            var q: Array=r.pick(edges)
            if M.distance(q[0],q[1],b[0],b[1])<5 and M.distance(q[0],q[1],a[0],a[1])>4:
                b=q
        var power: float=(.75 if (f&1) else .95)*r.between(.6,1)
        lightning.crackle(p,L.zigzag(M.rng_for([seed_value,8,f,i]),a[0],a[1],b[0],b[1],.42,.35),power,c,.4)
        d=batch.begin(p)
        for q in edges:
            if M.distance(q[0],q[1],a[0],a[1])<3.5 or M.distance(q[0],q[1],b[0],b[1])<3:
                d.px(q[0]-.5,q[1]-.5,c[5])
        batch.finish()
    if r.next()<(.9 if not j.is_empty() else .35):
        var side: int=r.sign()
        var x0: float=side*r.between(3,8)
        lightning.crackle(p,L.zigzag(M.rng_for([seed_value,9,f]),x0,-1.5,x0+side*r.between(5,12),-.5,.45,.3),.7,c,.35)
        d=batch.begin(p)
        d.glow(x0,-1,10,c[5],.35)
        batch.finish()
    d=batch.begin(p)
    for z in JOLTS:
        var age: float=M.wrap_period(t-z[0]/30.0,2)
        for i in range(9):
            var q=M.rng_for([seed_value,21,z[0],i])
            var life: float=q.between(.18,.4)
            if age>=life:
                continue
            var pt: Array=edges[int(floor(q.next()*edges.size()))]
            var ang: float=atan2(pt[1]+19,pt[0])+q.between(-.7,.7)
            var sp: float=q.between(60,150)*z[1]
            var fly: Array=L.flight(pt[0],pt[1],cos(ang)*sp,sin(ang)*sp-30,age,0)
            L.spark(d,fly[0],fly[1],fly[2],fly[3],1-age/life,sparks)
    MOTION.cycle(t,2,8,seed_value+3,func(g): return g.between(.15,.3),func(age: float,life: float,q,_i: int):
        var pt: Array=edges[int(floor(q.next()*edges.size()))]
        var ang: float=atan2(pt[1]+19,pt[0])+q.between(-.6,.6)
        var sp: float=q.between(50,110)
        var fly: Array=L.flight(pt[0],pt[1],cos(ang)*sp,sin(ang)*sp-20,age,0)
        L.spark(d,fly[0],fly[1],fly[2],fly[3],1-age/life,sparks)
    )
    batch.finish()
