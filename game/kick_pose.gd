extends RefCounted
## Front kick, right-facing local targets. Rear foot stays planted.
## Based on chamber/extension/retraction silhouettes in Martial Arts front_kick.
const DURATION=84
const ACTIVE_FROM=24
const ACTIVE_TO=34
const DAMAGE=18
const KNOCKBACK=195.0
const HURT=40
const HITSTOP=8
# tick, blend, pelvis, torso angle, near wrist, far wrist, near ankle (root local)
const KEYS=[
    [0,0.0,Vector2(0,-50),0.0,Vector2(22,0),Vector2(7,10),Vector2(24,-2)],
    [8,1.0,Vector2(-9,-48),-8.0,Vector2(19,1),Vector2(8,8),Vector2(24,-2)],
    [17,1.0,Vector2(-10,-53),-13.0,Vector2(17,3),Vector2(5,8),Vector2(13,-48)],
    [23,1.0,Vector2(-8,-53),-19.0,Vector2(15,6),Vector2(4,11),Vector2(33,-52)],
    [27,1.0,Vector2(-5,-53),-22.0,Vector2(12,9),Vector2(2,14),Vector2(53,-60)],
    [34,1.0,Vector2(-6,-53),-19.0,Vector2(14,7),Vector2(4,12),Vector2(52,-58)],
    [45,1.0,Vector2(-10,-52),-12.0,Vector2(18,4),Vector2(6,9),Vector2(16,-45)],
    [62,1.0,Vector2(-5,-49),-5.0,Vector2(20,0),Vector2(7,10),Vector2(23,-2)],
    [84,0.0,Vector2(0,-50),0.0,Vector2(22,0),Vector2(7,10),Vector2(24,-2)]
]
static func pose(tick:int)->Dictionary:
    var a:Array=KEYS[0]
    var b:Array=KEYS[1]
    for i in range(1,KEYS.size()):
        if tick<=int(KEYS[i][0]):
            a=KEYS[i-1]
            b=KEYS[i]
            break
    var u:float=clampf(float(tick-int(a[0]))/float(int(b[0])-int(a[0])),0,1)
    u=u*u*(3-2*u)
    return {"weight":lerpf(float(a[1]),float(b[1]),u),"hip":Vector2(a[2]).lerp(b[2],u),"lean":lerpf(float(a[3]),float(b[3]),u),"lead":Vector2(a[4]).lerp(b[4],u),"rear":Vector2(a[5]).lerp(b[5],u),"kick_foot":Vector2(a[6]).lerp(b[6],u)}
