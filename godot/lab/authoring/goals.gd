extends RefCounted
const Leg=preload("res://lab/leg_constraints_082.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
static func phase(k,clock:String)->float:
    if clock=="action":
        if k.action=="":return -1.
        return float(k.age)/maxi(1,k.bank[k.action].frames.size()-1)
    var gait=k.gait
    if clock=="cycle":
        return .5*(gait.side+(gait.travel-gait.queue[0])/(gait.queue[1]-gait.queue[0]))
    var side:int=0 if clock=="swing_near" else 1
    var leg:Dictionary=gait.legs[side]
    var start:float=leg.start+gait.STANCE_DISTANCE
    if gait.travel<start:return -1.
    return (gait.travel-start)/(leg.end-start)

# At most one winning target per arm/leg; ties follow document order.
static func resolve(k,p:Dictionary,paths:Array,legs:bool,goals:Array)->void:
    var owned:Dictionary={}
    for g in goals:
        var knee:bool=g.joint.begins_with("knee")
        var foot:bool=g.joint.begins_with("foot") or knee
        if foot!=legs:continue
        var t:=phase(k,g.clock)
        if t<0.:continue
        var dist:=absf(t-g.center)
        if g.clock=="cycle":dist=minf(dist,1.-dist)
        var w:float=g.weight*(1.-smoothstep(0.,g.width,dist))
        if w<=0.:continue
        var side:String=g.joint.get_slice("_",1)
        var chain:String=("leg_" if foot else "arm_")+side
        if owned.has(chain):continue
        owned[chain]=true
        var index:int=0 if side=="near" else 1
        var goal:Vector2=g.xy
        var reason:="мягкая цель" if w<.999 else "цель"
        if foot:
            if paths[index].stance:reason="стопа в опоре"
            else:
                var swing:=phase(k,"swing_"+side)
                if k.released.has(side):w*=k.released[side][0]
                else:w*=smoothstep(0.,.08,swing)*(1.-smoothstep(.92,1.,swing))
                var target_toe:=goal
                if knee:
                    # Estimate the already constrained swing, rotate its two
                    # fixed-length segments about the hip, then solve the
                    # common support problem once more with the new toe goal.
                    var trial:=p.duplicate(true)
                    k.support.resolve(trial,paths)
                    var hip:Vector2=k.rig.point("thigh_"+side)
                    var upper:Vector2=k.rig.point(g.joint)-hip
                    var ankle:Vector2=k.rig.point("foot_"+side)-hip
                    var rotation:=upper.angle_to(goal-hip)
                    target_toe=hip+ankle.rotated(rotation)+k.LegIK.toe_vector(trial,side)
                    target_toe.y=minf(0.,target_toe.y)
                    if absf(upper.length()-hip.distance_to(goal))>.05:reason="фиксированная длина бедра"
                paths[index].toe=Grid.point(Vector2(paths[index].toe).lerp(target_toe,w))
        else:
            k.rig.evaluate(p)
            var start:Vector2=k.rig.point(g.joint)
            var target:=start.lerp(goal,w)
            if g.joint.begins_with("hand"):
                var result:Dictionary=k.rig.aim_arm(p,g.joint,target)
                for joint in ["shoulder_"+side,"elbow_"+side]:p.angles[joint]=Grid.scalar(result.pose.angles[joint])
                if result.clamp_distance>.01:reason="предел длины руки"
                var elbow:String="elbow_"+side
                var rest_upper:Vector2=k.rig.joints[k.rig.ids[elbow]].offset
                var rest_lower:Vector2=k.rig.joints[k.rig.ids[g.joint]].offset
                var rest:=rad_to_deg(rest_upper.angle_to(rest_lower))
                var bend:=wrapf(p.angles[elbow]+rest,-180.,180.)
                if absf(bend)>170.:
                    p.angles[elbow]=Grid.scalar(clampf(bend,-170.,170.)-rest)
                    reason="предел сгиба локтя"
            else:
                var pivot:Vector2=k.rig.point("shoulder_"+side)
                p.angles["shoulder_"+side]=Grid.scalar(p.angles["shoulder_"+side]+rad_to_deg((start-pivot).angle_to(target-pivot)))
        k.goal_report[g.joint]={"target":goal,"reason":reason,"index":g.order,"weight":w}
