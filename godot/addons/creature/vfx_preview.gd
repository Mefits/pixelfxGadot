extends RefCounted
## Stateless authored-clip preview. Separate rig prevents editing side effects.
const C=preload("res://addons/creature/clips.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const RIG=preload("res://addons/creature/rig.gd")
const MAX_ACTIVE=12
var renderer=R.new()
var rig=RIG.humanoid()
var active: int=0
var skipped: int=0
var points: Dictionary={}
func joint_at(clip: Dictionary,id: String,t: float) -> Vector2:
    var at: float=clampf(t,0,float(clip.duration))
    var key: Vector2=Vector2(at,rig.ids[id])
    if points.has(key):return points[key]
    rig.evaluate(C.sample(clip,at,false))
    var value: Vector2=rig.point(id)
    points[key]=value
    return value

func draw(painter,clip: Dictionary,time: float,origin: Vector2,target: Vector2,facing: int=1) -> void:
    painter.clear()
    active=0
    skipped=0
    points.clear()
    var events: Array=clip.events.duplicate()
    events.sort_custom(func(a,b):return float(a.t)<float(b.t))
    for e in events:
        if e.kind!="vfx" or not rig.ids.has(e.anchor):continue
        var start: float=float(e.t)
        var age: float=time-start
        if age<0 or age>=P.duration(e.preset):continue
        if active>=MAX_ACTIVE:
            skipped+=1
            continue
        var id: String=e.anchor
        var base: Vector2=joint_at(clip,id,start)
        var world: Vector2=origin+Vector2(base.x*facing,base.y)
        var provider: Callable=func(name:String,local_time:float)->Vector2:
            if name=="target":
                var q: Vector2=target-world
                return Vector2(q.x*facing,q.y)
            return joint_at(clip,id,start+local_time)-base
        renderer.render(painter,e.preset,age,{},origin.y-world.y,provider,false,world,facing<0)
        active+=1
    painter.place(0,0)
