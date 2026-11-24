extends RefCounted
## One authored jab, no combo or secondary physics. Fixed 120 Hz.
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
var age:int=-1
var hurt:int=0
var hp:int=100
var attacks:int=0
var connected:bool=false
var latch:bool=false
var queued:bool=false
func capture(pressed:bool)->void:
    if pressed and not latch:queued=true
    latch=pressed
func tick(m)->void:
    if hurt>0:hurt-=1
    if age>=0:
        age+=1
        if age>=DURATION:age=-1
    if queued and hp>0 and hurt==0 and age<0 and m.grounded:
        age=0
        connected=false
        attacks+=1
    queued=false
func locked()->bool:return age>=0 or hurt>0 or hp<=0
func active()->bool:return age>=ACTIVE_FROM and age<=ACTIVE_TO and not connected
func receive(m,direction:int)->void:
    hp=maxi(0,hp-DAMAGE)
    age=-1
    hurt=HURT_TICKS
    queued=false
    m.velocity.x=KNOCKBACK*direction
func pose()->Dictionary:
    if hurt>0:
        var u:float=float(hurt)/HURT_TICKS
        return {"weight":u,"hip":Vector2(-3,-47),"lean":-24.0,"lead":Vector2(8,19),"rear":Vector2(-6,20)}
    if age<0:return {}
    var a:Array=KEYS[0]
    var b:Array=KEYS[1]
    for i in range(1,KEYS.size()):
        if age<=int(KEYS[i][0]):
            a=KEYS[i-1]
            b=KEYS[i]
            break
    var u:float=float(age-int(a[0]))/float(int(b[0])-int(a[0]))
    u=u*u*(3-2*u)
    return {"weight":lerpf(float(a[1]),float(b[1]),u),"hip":Vector2(lerpf(float(a[2]),float(b[2]),u),lerpf(float(a[3]),float(b[3]),u)),"lean":lerpf(float(a[4]),float(b[4]),u),"lead":Vector2(a[5]).lerp(b[5],u),"rear":Vector2(a[6]).lerp(b[6],u)}
