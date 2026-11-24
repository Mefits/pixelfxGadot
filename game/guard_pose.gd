extends RefCounted
## Right-facing guard, hand-transcribed from user's eight-frame stickman sheet.
## Units: art pixels and degrees. No sprite pixels copied. Root stays fixed.
const DURATION=1.2
const HALF_WIDTH=24.0
# time, pelvis x/y, forward torso angle, head tilt from vertical,
# lead hand offset from lead shoulder, rear hand offset from rear shoulder.
# Frames 1, 3, 4/5, 6, 8. Last is an exact loop of first.
const KEYS=[
    [0.0, 1.0,-53.0, 1.0,26.0, 22.0,-1.0, 5.0,10.0],
    [.30,-.5,-50.0, 3.0,36.0, 21.0, 5.0, 6.0,14.0],
    [.60,-2.0,-47.0, 5.0,43.0, 20.0, 9.0, 7.0,17.0],
    [.90, 0.0,-51.0, 2.0,30.0, 22.0, 2.0, 5.5,12.0],
    [1.2, 1.0,-53.0, 1.0,26.0, 22.0,-1.0, 5.0,10.0]
]
static func sample(seconds:float)->Dictionary:
    var t:float=fposmod(seconds,DURATION)
    var k:Array=KEYS[0]
    var n:Array=KEYS[1]
    for i in range(1,KEYS.size()):
        if t<=float(KEYS[i][0]):
            k=KEYS[i-1]
            n=KEYS[i]
            break
    var u:float=(t-float(k[0]))/(float(n[0])-float(k[0]))
    u=u*u*(3-2*u)
    var v:Array[float]=[]
    for i in range(1,k.size()):v.append(lerpf(float(k[i]),float(n[i]),u))
    return {"hip":Vector2(v[0],v[1]),"torso":v[2],"head":v[3],"lead":Vector2(v[4],v[5]),"rear":Vector2(v[6],v[7])}
