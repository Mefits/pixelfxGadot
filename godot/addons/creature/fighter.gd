extends RefCounted
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const FLOOR: float=146.0
var rig=RIG.humanoid()
var bank: Dictionary
var pos: Vector2
var velocity: Vector2=Vector2.ZERO
var facing: int=1
var hp: int=100
var state: String="idle"
var t: float=0
var guard: bool=false
var hitstun: float=0
var events: Array=[]
var tint: Color

func _init(x: float,side: int,c: Color,clips: Dictionary) -> void:
    pos=Vector2(x,FLOOR)
    facing=side
    tint=c
    bank=clips
    rig.evaluate(CLIPS.sample(bank.idle,0))

func point(id: String) -> Vector2:
    var q: Vector2=rig.point(id)
    return pos+Vector2(q.x*facing,q.y)

func start(name: String) -> void:
    state=name
    t=0

func step(dt: float,move: float,jump: bool,strike: bool,cast: bool,block: bool,enemy_x: float) -> void:
    events.clear()
    if hp<=0:
        guard=false
        return
    var locked: bool=state in ["strike","cast"] and t<float(bank[state].duration)
    hitstun=maxf(0,hitstun-dt)
    if hitstun<=0 and not locked:
        facing=1 if enemy_x>=pos.x else -1
        guard=block
        if strike and not block:
            start("strike")
        elif cast and not block:
            start("cast")
        else:
            if jump and pos.y>=FLOOR-.01 and not block:
                velocity.y=-118
            var wanted: String="jump" if pos.y<FLOOR-.01 or velocity.y<0 else ("guard" if block else ("walk" if absf(move)>.1 else "idle"))
            if state!=wanted: start(wanted)
        velocity.x=move*(18 if block else 53) if not state in ["strike","cast"] else 0.0
    else:
        guard=false
        velocity.x=move_toward(velocity.x,0,dt*150)
    velocity.y+=dt*340
    pos+=velocity*dt
    if pos.y>FLOOR:
        pos.y=FLOOR
        velocity.y=0
    pos.x=clampf(pos.x,16,304)
    var old: float=t
    t+=dt
    var clip: Dictionary=bank[state]
    if state in ["strike","cast"]:
        events=CLIPS.events_between(clip,old,t)
    rig.evaluate(CLIPS.sample(clip,t))

func damage(amount: int,direction: int) -> void:
    var blocked: bool=guard and direction==facing*-1
    hp=maxi(0,hp-(maxi(1,int(amount/4.0)) if blocked else amount))
    if not blocked:
        hitstun=.24
        start("hurt")
        velocity.x=direction*45
        rig.evaluate(CLIPS.sample(bank.hurt,0))
