extends RefCounted
## Analytic two-link IK with an explicit bend side in facing-right space.
## The actual render rig is also the future physics attachment contract.
const GUARD=preload("res://game/guard_pose.gd")
const TORSO=34.0
const NECK=22.0
const UPPER_LEG=30.0
const LOWER_LEG=30.0
const UPPER_ARM=22.0
const LOWER_ARM=23.0
var points:Dictionary={}
static func chain(a:Vector2,target:Vector2,l1:float,l2:float,bend:float)->Array[Vector2]:
    var delta:Vector2=target-a
    var direction:Vector2=delta.normalized() if delta.length()>.0001 else Vector2.DOWN
    var d:float=clampf(delta.length(),absf(l1-l2)+.01,l1+l2-.01)
    var along:float=(l1*l1-l2*l2+d*d)/(2*d)
    var height:float=sqrt(maxf(0,l1*l1-along*along))
    var end:Vector2=a+direction*d
    var joint:Vector2=a+direction*along+Vector2(-direction.y,direction.x)*height*bend
    return [joint,end]
func sample(m)->Dictionary:
    var direction:float=float(m.facing)
    var speed:float=absf(m.velocity.x)
    var relative:float=m.velocity.x*direction
    var g:Dictionary=GUARD.sample(m.guard_phase)
    var moving:float=clampf(m.gait,0,1) if m.grounded else 1.0
    var lean:float=lerpf(float(g.torso),clampf(relative/215.0,-1,1)*16,moving)
    var hip_x:float=lerpf(float(g.hip.x),0,moving)
    var hip_y:float=lerpf(float(g.hip.y),-50,moving)+4*m.land
    if m.grounded:
        # Keep BOTH target feet within the reach envelope while grounded.
        for i in range(2):
            var foot:Vector2=m.feet[i]
            var dx:float=absf((foot.x-m.pos.x)*direction-hip_x-(2 if i==0 else -2))
            var max_height:float=sqrt(maxf(4,59.7*59.7-minf(dx,58)*minf(dx,58)))
            hip_y=maxf(hip_y,foot.y-m.pos.y-2-max_height)
    var hip:=Vector2(hip_x,hip_y)
    var chest:=hip+Vector2(0,-TORSO).rotated(deg_to_rad(lean))
    var head:=chest+Vector2(0,-NECK).rotated(deg_to_rad(lerpf(float(g.head),lean*.6,moving)))
    var local:Dictionary={"hips":hip,"chest":chest,"head":head}
    for i in range(2):
        var side:String="near" if i==0 else "far"
        var side_sign:float=1 if i==0 else -1
        var shoulder:Vector2=chest+Vector2(5*side_sign,2).rotated(deg_to_rad(lean))
        var thigh:Vector2=hip+Vector2(2*side_sign,0)
        var foot:Vector2
        if m.grounded:
            foot=Vector2((m.feet[i].x-m.pos.x)*direction,m.feet[i].y-m.pos.y-2)
        else:
            var rising:float=clampf(-m.velocity.y/395.0,0,1)
            foot=hip+Vector2(side_sign*(12+9*rising),38-13*rising)
        # A planted leg bends toward the opponent; the elbow bends downward.
        var leg:Array[Vector2]=chain(thigh,foot,UPPER_LEG,LOWER_LEG,-1)
        var stride:float=clampf((foot.x-hip.x)/24,-1,1)
        var guard:Vector2=g.lead if i==0 else g.rear
        var travel:Vector2=Vector2(-stride*15,25-absf(stride)*4)
        var hand_goal:Vector2=shoulder+guard.lerp(travel,moving*.75)
        if not m.grounded:hand_goal=shoulder+Vector2(12*side_sign,10)
        var arm:Array[Vector2]=chain(shoulder,hand_goal,UPPER_ARM,LOWER_ARM,1)
        local["shoulder_"+side]=shoulder
        local["elbow_"+side]=arm[0]
        local["hand_"+side]=arm[1]
        local["thigh_"+side]=thigh
        local["knee_"+side]=leg[0]
        local["foot_"+side]=leg[1]
    points={}
    for key in local:
        var p:Vector2=local[key]
        points[key]=m.pos+Vector2(p.x*direction,p.y)
    return points
