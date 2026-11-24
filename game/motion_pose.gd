extends RefCounted
## Pose targets, hand-authored from Craftpix side-view sheets, not copied sprite pixels.
## Running: forward torso lean, high recovery knee and opposed bent arms.
## Jump: reach -> tuck -> extension; landing uses the motor's damped contact envelope.
static func air(m,side:int)->Dictionary:
    var s:float=1.0 if side==0 else -1.0
    var t:float=m.airborne_time
    var phase:float=clampf(t/.78,0,1)
    var takeoff:float=smoothstep(0.0,.12,t)
    var tuck:float=smoothstep(.07,.29,t)*(1.0-smoothstep(.43,.70,t))
    var extend:float=smoothstep(.46,.76,t)
    var f:Vector2=Vector2(s*(16+8*tuck),-5-26*tuck)
    if side==1:f.y+=8*tuck
    if m.takeoff_feet.size()==2:f=Vector2(m.takeoff_feet[side]).lerp(f,takeoff)
    f=f.lerp(Vector2(s*24,-2),extend)
    var hand:Vector2=Vector2(17.0 if side==0 else 7.0,11.0)
    hand=hand.lerp(Vector2(27.0 if side==0 else -4.0,-12.0 if side==0 else 16.0),tuck)
    hand=hand.lerp(Vector2(19.0 if side==0 else 9.0,12.0),extend)
    return {"foot":f,"hand":hand,"lean":lerpf(12.0,25.0,tuck)*(1.0-extend)+4.0*extend,"hip_y":-50.0+6.0*tuck,"phase":phase}
static func arm_target(stride:float,run:float,side:int)->Vector2:
    var upper:float=stride*lerpf(24.0,48.0,run)
    var elbow:float=lerpf(35.0,91.0,run)
    return Vector2(0,22).rotated(deg_to_rad(upper))+Vector2(0,23).rotated(deg_to_rad(upper-elbow))
