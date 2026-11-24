extends RefCounted
## Three authored attacks and optional bounded spring reaction. Fixed 120 Hz.
const REACTION=preload("res://game/impact_reaction.gd")
const KICK=preload("res://game/kick_pose.gd")
const HEAVY_DURATION=80
const HEAVY_ACTIVE_FROM=24
const HEAVY_ACTIVE_TO=36
const HEAVY_DAMAGE=25
const HEAVY_KNOCKBACK=235.0
const HEAVY_HURT=50
const HEAVY_HITSTOP=10
const DURATION=48
const ACTIVE_FROM=12
const ACTIVE_TO=23
const HURT_TICKS=26
const DAMAGE=10
const KNOCKBACK=145.0
const HITSTOP=6
# tick, blend, hip x/y, chest angle, lead/rear wrist relative to shoulder
# Martial Arts jab right-facing row: compact start, extension, hold, recovery.
const KEYS=[
    [0,0.0,0.0,-50.0,0.0,Vector2(20,0),Vector2(7,10)],
    [7,1.0,-3.0,-49.0,-5.0,Vector2(14,5),Vector2(9,7)],
    [12,1.0,4.0,-51.0,12.0,Vector2(40,-1),Vector2(9,6)],
    [15,1.0,7.0,-51.0,17.0,Vector2(44,-2),Vector2(8,5)],
    [22,1.0,6.0,-51.0,14.0,Vector2(43,-1),Vector2(8,6)],
    [32,1.0,2.0,-50.0,6.0,Vector2(25,5),Vector2(7,10)],
    [48,0.0,0.0,-50.0,0.0,Vector2(20,0),Vector2(7,10)]
]
# Heavy uses the rear fist, compact preparation, full torso drive and longer recovery.
const HEAVY_KEYS=[
    [0,0.0,0.0,-50.0,0.0,Vector2(20,0),Vector2(7,10)],
    [10,1.0,-5.0,-48.0,-12.0,Vector2(17,2),Vector2(-12,9)],
    [20,1.0,-1.0,-49.0,-4.0,Vector2(17,5),Vector2(3,8)],
    [24,1.0,6.0,-51.0,19.0,Vector2(10,9),Vector2(42,-2)],
    [29,1.0,9.0,-51.0,28.0,Vector2(6,10),Vector2(44,-3)],
    [36,1.0,7.0,-50.0,23.0,Vector2(8,10),Vector2(42,0)],
    [51,1.0,1.0,-49.0,8.0,Vector2(17,5),Vector2(20,13)],
    [80,0.0,0.0,-50.0,0.0,Vector2(20,0),Vector2(7,10)]
]
var reaction=REACTION.new()
var kind:String="jab"
var heavy_latch:bool=false
var kick_latch:bool=false
var kick_pending:int=0
var queued_kind:String="jab"
var hurt_total:int=HURT_TICKS
var hurt_heavy:bool=false
var age:int=-1
var hurt:int=0
var hp:int=100
var attacks:int=0
var connected:bool=false
var latch:bool=false
var queued:bool=false
func capture(pressed:bool,heavy:bool=false,kick:bool=false)->void:
    if kick and not kick_latch:
        queued=true
        queued_kind="kick"
    elif heavy and not heavy_latch:
        queued=true
        queued_kind="heavy"
    elif pressed and not latch:
        queued=true
        queued_kind="jab"
    latch=pressed
    heavy_latch=heavy
    kick_latch=kick
func duration()->int:
    if kind=="kick":return KICK.DURATION
    return HEAVY_DURATION if kind=="heavy" else DURATION
func fist()->String:
    if kind=="kick":return "foot_near"
    return "hand_far" if kind=="heavy" else "hand_near"
func contact_point(rig,face:int)->Vector2:
    var p:Vector2=rig.points[fist()]
    # Kick reaches the visible forefoot, rather than the ankle joint alone.
    if kind=="kick":p.x+=9*face
    return p
func kicking()->bool:return kind=="kick" and age>=0
func profile()->Dictionary:
    if kind=="kick":return {"damage":KICK.DAMAGE,"knockback":KICK.KNOCKBACK,"hurt":KICK.HURT,"freeze":KICK.HITSTOP,"strength":1.6,"heavy":true}
    return {"damage":HEAVY_DAMAGE,"knockback":HEAVY_KNOCKBACK,"hurt":HEAVY_HURT,"freeze":HEAVY_HITSTOP,"strength":2.0,"heavy":true} if kind=="heavy" else {"damage":DAMAGE,"knockback":KNOCKBACK,"hurt":HURT_TICKS,"freeze":HITSTOP,"strength":1.0,"heavy":false}
func tick(m)->void:
    reaction.step()
    if hurt>0:hurt-=1
    if age>=0:
        age+=1
        if age>=duration():age=-1
    if kick_pending>0:kick_pending-=1
    if not m.grounded or hurt>0 or hp<=0:kick_pending=0
    if queued and hp>0 and hurt==0 and age<0 and m.grounded:
        if queued_kind=="kick":kick_pending=48
        else:
            kick_pending=0
            age=0
            kind=queued_kind
            connected=false
            attacks+=1
    if kick_pending>0 and age<0 and m.grounded and m.swing<0 and absf(m.velocity.x)<=20:
        age=0
        kind="kick"
        connected=false
        attacks+=1
        kick_pending=0
    queued=false
func locked()->bool:return age>=0 or hurt>0 or hp<=0
func active()->bool:
    if kind=="kick":return age>=KICK.ACTIVE_FROM and age<=KICK.ACTIVE_TO and not connected
    return age>=(HEAVY_ACTIVE_FROM if kind=="heavy" else ACTIVE_FROM) and age<=(HEAVY_ACTIVE_TO if kind=="heavy" else ACTIVE_TO) and not connected
func receive(m,direction:int,attack:Dictionary,lever:float)->void:
    hp=maxi(0,hp-int(attack.damage))
    age=-1
    hurt=int(attack.hurt)
    hurt_total=hurt
    hurt_heavy=bool(attack.heavy)
    queued=false
    kick_pending=0
    m.velocity.x=float(attack.knockback)*direction
    reaction.impulse(float(attack.strength),lever,float(direction*m.facing))
func pose(hybrid:bool=false)->Dictionary:
    if hurt>0:
        var u:float=float(hurt)/hurt_total
        if hybrid:
            # Small authored loss of balance; actual upper-body motion comes from springs.
            return {"weight":u*.55,"hip":Vector2(-2,-45 if hurt_heavy else -48),"lean":-5.0,"lead":Vector2(16,8),"rear":Vector2(6,12)}
        return {"weight":u,"hip":Vector2(-5,-44) if hurt_heavy else Vector2(-3,-47),"lean":-36.0 if hurt_heavy else -24.0,"lead":Vector2(8,19),"rear":Vector2(-6,20)}
    if age<0:return {}
    if kind=="kick":return KICK.pose(age)
    var keys:Array=HEAVY_KEYS if kind=="heavy" else KEYS
    var a:Array=keys[0]
    var b:Array=keys[1]
    for i in range(1,keys.size()):
        if age<=int(keys[i][0]):
            a=keys[i-1]
            b=keys[i]
            break
    var u:float=float(age-int(a[0]))/float(int(b[0])-int(a[0]))
    u=u*u*(3-2*u)
    return {"weight":lerpf(float(a[1]),float(b[1]),u),"hip":Vector2(lerpf(float(a[2]),float(b[2]),u),lerpf(float(a[3]),float(b[3]),u)),"lean":lerpf(float(a[4]),float(b[4]),u),"lead":Vector2(a[5]).lerp(b[5],u),"rear":Vector2(a[6]).lerp(b[6],u)}
