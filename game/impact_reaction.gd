extends RefCounted
## Bounded angular dynamics in facing-right space, degrees and seconds.
## The pelvis/root is driven by the motor. These channels are visual/pose
## dynamics, not a free ragdoll or independent rigid-body collider.
const DT=1.0/120.0
const LIMITS=Vector4(38,32,50,50)
var angles:=Vector4.ZERO # torso, head, near arm, far arm
var speeds:=Vector4.ZERO
var impacts:int=0
func clear()->void:
    angles=Vector4.ZERO
    speeds=Vector4.ZERO
func impulse(strength:float,lever:float,direction:float)->void:
    # Torque scales with the lever arm above the pelvis. Direction is local.
    var torque:float=clampf(strength,0,2.5)*clampf(lever,.2,1.2)*clampf(direction,-1,1)
    speeds.x=clampf(speeds.x+torque*510,-1100,1100)
    # The other channels receive force through the torso, not a synchronized key.
    impacts+=1
func step()->void:
    # Semi-implicit spring integration, fixed dt. Coupling gives secondary lag.
    var target:=Vector4(0,angles.x*.85,-angles.x*.72,angles.x*.52)
    var stiffness:=Vector4(120,145,108,92)
    var damping:=Vector4(17,14,13,12)
    for i in range(4):
        speeds[i]+=(stiffness[i]*(target[i]-angles[i])-damping[i]*speeds[i])*DT
        var raw:float=angles[i]+speeds[i]*DT
        angles[i]=clampf(raw,-LIMITS[i],LIMITS[i])
        if raw < -LIMITS[i] or raw > LIMITS[i]:speeds[i]=0
    if angles.length()<.03 and speeds.length()<.2:clear()
func finite()->bool:
    return angles.is_finite() and speeds.is_finite()
