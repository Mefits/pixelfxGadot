extends RefCounted
## Fixed-tick visual-only event runtime. All samples are local to the event's
## initial world anchor, mirrored by the caster's facing. No damage or physics.
const P=preload("res://addons/pixelfx/composer/preset.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const B=preload("res://addons/creature/vfx_bindings.gd")
const MAX_ACTIVE=12
const MAX_SAMPLES=2048
const DT: float=1.0/120.0
var bank: Dictionary={}
var active: Array=[]
var renderer=R.new()
var dropped: int=0

func _init(bindings: Dictionary={}) -> void:
    if B.valid(bindings):bank=bindings.duplicate(true)

func spawn(role: String,owner,anchor: String,at: Vector2,target: Vector2,facing: int) -> bool:
    if not bank.has(role):return false
    return spawn_preset(bank[role],owner,anchor,at,target,facing)

# Presets are validated at clip/bank load, not during combat.
func spawn_preset(preset: Dictionary,owner,anchor: String,at: Vector2,target: Vector2,facing: int) -> bool:
    if active.size()>=MAX_ACTIVE:
        dropped+=1
        return false
    var direction: int=-1 if facing<0 else 1
    var item: Dictionary={"preset":preset,"owner":owner,"anchor":anchor,"base":at,"target":target,"facing":direction,"age":0.0,"samples":PackedVector2Array([Vector2.ZERO])}
    active.append(item)
    return true

func advance() -> void:
    # Called only on non-frozen simulation ticks, never on a render frame.
    for i in range(active.size()-1,-1,-1):
        var item: Dictionary=active[i]
        item.age=float(item.age)+DT
        if item.age>=P.duration(item.preset) or item.samples.size()>=MAX_SAMPLES:
            active.remove_at(i)
            continue
        var q: Vector2=item.base
        if item.owner!=null:q=item.owner.point(item.anchor)
        var local: Vector2=q-Vector2(item.base)
        local.x*=float(item.facing)
        var samples: PackedVector2Array=item.samples
        samples.append(local)
        item.samples=samples

static func sample(item: Dictionary,name: String,t: float) -> Vector2:
    if name=="target":
        var v: Vector2=Vector2(item.target)-Vector2(item.base)
        v.x*=float(item.facing)
        return v
    var samples: PackedVector2Array=item.samples
    var index: float=clampf(t/DT,0,samples.size()-1)
    var left: int=int(floor(index))
    return samples[left].lerp(samples[mini(left+1,samples.size()-1)],index-left)

func draw(painter,floor_y: float) -> void:
    for item in active:
        var provider: Callable=func(name:String,t:float)->Vector2:
            return sample(item,name,t)
        renderer.render(painter,item.preset,float(item.age),{},floor_y-float(item.base.y),provider,false,Vector2(item.base),int(item.facing)<0)
    painter.place(0,0)
