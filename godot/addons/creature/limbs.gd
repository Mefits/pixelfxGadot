extends RefCounted
## Procedural feet, independent from the visual skin. World-space planted contacts
## apply bounded forces to the body; analytical two-link IK is display geometry.
var legs: Array[Dictionary]=[]
var enabled: bool=true
var support_count: int=0
var steps_taken: int=0
var rest_height: float=18
var upper: float=14
var lower: float=14
var stride: float=12
var max_reach: float=27
var swing_time: float=.14
var phase: int=0
var step_clock: float=0
var last_dir: float=1
var surface_normal:=Vector2.UP
var current_height: float=18
var override_leg: int=-1
var rear_height_offset: float=0
var front_height_offset: float=0
var adaptive_gait: bool=true
var foot_lift: float=6
var contact_polish: bool=true
var landing_offset: float=0
var recovery_steps: int=0
var knee_avoids: int=0

func setup(body) -> void:
    legs.clear()
    for i in range(4):
        var parent: int=0 if i<2 else 1
        var hip: Vector2=body.nodes[parent].p
        legs.append({"parent":parent,"side":-1 if i%2==0 else 1,"group":i%2 if parent==0 else 1-i%2,"foot":hip+Vector2(0,rest_height),"knee":hip,"start":hip,"target":hip,"planted":false,"swing":false,"age":0.0})
    support_count=0
    surface_normal=Vector2.UP
    phase=0
    step_clock=0

func _blocked(a: Vector2,b: Vector2,boxes: Array[Rect2]) -> bool:
    # Test the open segment (the endpoint itself is on the surface).
    for i in range(1,8):
        var p: Vector2=a.lerp(b,float(i)/8)
        for box in boxes:
            if box.has_point(p):return true
    return false

func find_support(hip: Vector2,wanted_x: float,boxes: Array[Rect2]) -> Dictionary:
    var best: float=INF
    var result: Dictionary={}
    for box in boxes:
        if box.size.x<4 or box.position.y<hip.y+3 or box.position.y>hip.y+max_reach:
            continue
        var x: float=clampf(wanted_x,box.position.x+1,box.end.x-1)
        var foot:=Vector2(x,box.position.y-.15)
        if hip.distance_to(foot)>max_reach or _blocked(hip,foot,boxes):continue
        var score: float=absf(x-wanted_x)*1.5+absf(foot.y-hip.y-rest_height)
        if score<best:
            best=score
            result={"foot":foot}
    return result

func release_all() -> void:
    for l in legs:
        l.planted=false
        l.swing=false
    support_count=0

func step(body,dt: float,axis: float,direction: float,allow_support: bool) -> void:
    support_count=0
    if surface_normal!=Vector2.UP:
        release_all()
        surface_normal=Vector2.UP
    if not enabled:
        release_all()
        return
    if not allow_support:
        release_all()
        return
    step_clock+=dt
    if step_clock>=swing_time:
        step_clock=0
        phase=1-phase
    last_dir=direction
    # Refresh world-space contacts and choose a diagonal gait group.
    for i in range(legs.size()):
        var l: Dictionary=legs[i]
        if i==override_leg:
            l.planted=false
            l.swing=false
            continue
        var hip: Vector2=body.nodes[l.parent].p
        var bias: float=(4.0 if l.parent==0 else -4.0)*direction+float(l.side)*2
        var speed: float=body.nodes[l.parent].v.x
        var lead: float=axis*stride
        if adaptive_gait:lead=clampf(speed*.10,-stride,stride) if absf(axis)>.05 else 0.0
        var desired: float=hip.x+bias+lead
        var lost: bool=false
        if l.planted and (hip.distance_to(l.foot)>max_reach or _blocked(hip,l.foot,body.obstacles)):
            l.planted=false
            lost=true
        if l.swing:
            l.age+=dt
            var u: float=clampf(float(l.age)/float(l.get("swing_duration",swing_time)),0,1)
            l.foot=Vector2(l.start).lerp(l.target,u*u*(3-2*u))+Vector2(0,-sin(u*PI)*foot_lift)
            if u>=1:
                l.swing=false
                l.planted=hip.distance_to(l.target)<=max_reach and not _blocked(hip,l.target,body.obstacles)
                if l.planted:
                    l.foot=l.target
                    steps_taken+=1
        elif not l.planted:
            var candidate: Dictionary=find_support(hip,desired,body.obstacles)
            if not candidate.is_empty():
                # Recover a lost walking contact with a short swing if a sibling
                # still supports this chunk. Air-to-ground acquisition stays immediate.
                var supported: bool=false
                for other in legs:
                    if other.parent==l.parent and other.planted:supported=true;break
                if contact_polish and lost and supported:
                    l.start=l.foot
                    l.target=candidate.foot
                    l.age=0.0
                    l.swing_duration=.07
                    l.swing=true
                    recovery_steps+=1
                else:
                    l.foot=candidate.foot
                    l.planted=true
        elif (absf(axis)>.1 or (adaptive_gait and absf(speed)<15)) and l.group==phase and absf(float(l.foot.x)-desired)>(8 if adaptive_gait else 10):
            var candidate: Dictionary=find_support(hip,desired,body.obstacles)
            if not candidate.is_empty() and Vector2(l.foot).distance_to(candidate.foot)>5:
                l.start=l.foot
                l.target=candidate.foot
                l.planted=false
                l.swing=true
                l.age=0.0
                l.swing_duration=clampf(.14-absf(speed)*.00035,.09,.14) if adaptive_gait else swing_time
        if l.planted:support_count+=1
    # A planted foot is an actual support: spring-damper lifts its parent.
    # Divide by number of supporting legs on the same body chunk.
    for parent in range(2):
        var active: Array=[]
        for l in legs:
            if l.parent==parent and l.planted:active.append(l)
        if active.is_empty():continue
        var n: Dictionary=body.nodes[parent]
        var y: float=0
        for l in active:y+=float(l.foot.y)
        y/=active.size()
        var height: float=y-float(n.p.y)
        # Compress support posture below low ceilings, without shrinking collision circles.
        var desired_height: float=rest_height+(rear_height_offset if parent==1 else front_height_offset)+landing_offset
        for box in body.obstacles:
            if float(n.p.x)>=box.position.x-7 and float(n.p.x)<=box.end.x+7 and box.end.y<float(n.p.y) and box.end.y>y-40:
                desired_height=minf(desired_height,maxf(7.5,y-box.end.y-8))
        desired_height=maxf(7.5,desired_height)
        current_height=desired_height
        var ay: float=clampf(-body.gravity.y+(height-desired_height)*155-float(n.v.y)*23,-1250,0)
        body.force(parent,Vector2(0,ay/float(n.inv)))

func update_geometry(body,dt: float,direction: float) -> void:
    for i in range(legs.size()):
        if i==override_leg:continue
        var l: Dictionary=legs[i]
        var hip: Vector2=body.nodes[l.parent].p
        if not l.planted and not l.swing:
            var tuck:=Vector2(direction*(5 if l.parent==0 else -5)+float(l.side)*2,12)
            if contact_polish and surface_normal==Vector2.UP:
                var vy: float=body.nodes[l.parent].v.y
                if vy>15:
                    # Extend toward the next contact on descent, tuck during ascent.
                    tuck.y=lerpf(12,minf(max_reach-2,rest_height+5),clampf(vy/120,0,1))
                    tuck.x+=clampf(float(body.nodes[l.parent].v.x)*.045,-6,6)
                elif vy< -15:tuck.y=8
            if surface_normal!=Vector2.UP:tuck=-surface_normal*12+Vector2(0,float(l.side)*5)
            l.foot=Vector2(l.foot).lerp(hip+tuck,clampf(dt*18,0,1))
        # IK only draws a reachable endpoint, never teleports a physical chunk.
        var d: Vector2=Vector2(l.foot)-hip
        var length: float=clampf(d.length(),.001,upper+lower-.001)
        var axis: Vector2=d.normalized() if d.length_squared()>.000001 else Vector2.DOWN
        var along: float=(upper*upper-lower*lower+length*length)/(2*length)
        var bend: float=sqrt(maxf(0,upper*upper-along*along))
        var sign0: float=direction if l.parent==0 else -direction
        var tip: Vector2=hip+axis*length
        var knee: Vector2=hip+axis*along+axis.orthogonal()*bend*sign0
        if contact_polish and (_blocked(hip,knee,body.obstacles) or _blocked(knee,tip,body.obstacles)):
            var alternate: Vector2=hip+axis*along-axis.orthogonal()*bend*sign0
            if not _blocked(hip,alternate,body.obstacles) and not _blocked(alternate,tip,body.obstacles):
                knee=alternate
                knee_avoids+=1
        l.knee=knee
        l.tip=tip

func step_wall(body,dt: float,climb: float,normal: Vector2,face: Rect2) -> void:
    if surface_normal!=normal:
        release_all()
        surface_normal=normal
    support_count=0
    if not enabled:return
    step_clock+=dt
    if step_clock>=swing_time:
        step_clock=0
        phase=1-phase
    var edge: float=face.position.x if normal.x<0 else face.end.x
    for l in legs:
        var hip: Vector2=body.nodes[l.parent].p
        var wanted_y: float=hip.y+climb*stride+float(l.side)*4
        var target:=Vector2(edge+normal.x*.15,clampf(wanted_y,face.position.y+1,face.end.y-1))
        if l.planted and (hip.distance_to(l.foot)>max_reach or _blocked(hip,l.foot,body.obstacles)):
            l.planted=false
        if l.swing:
            l.age+=dt
            var u: float=clampf(float(l.age)/swing_time,0,1)
            l.foot=Vector2(l.start).lerp(l.target,u*u*(3-2*u))+normal*sin(u*PI)*5
            if u>=1:
                l.swing=false
                l.planted=hip.distance_to(l.target)<=max_reach and not _blocked(hip,l.target,body.obstacles)
                if l.planted:
                    l.foot=l.target
                    steps_taken+=1
        elif not l.planted:
            if hip.distance_to(target)<=max_reach and not _blocked(hip,target,body.obstacles):
                l.foot=target
                l.planted=true
        elif absf(climb)>.1 and l.group==phase and Vector2(l.foot).distance_to(target)>9 and hip.distance_to(target)<=max_reach:
            l.start=l.foot
            l.target=target
            l.planted=false
            l.swing=true
            l.age=0.0
        if l.planted:support_count+=1

func add_pair(body) -> bool:
    if legs.size()>=8:return false
    for parent in range(2):
        var hip: Vector2=body.nodes[parent].p
        var side: int=2 if legs.size()<6 else -2
        legs.append({"parent":parent,"side":side,"group":parent,"foot":hip+Vector2(0,rest_height),"knee":hip,"start":hip,"target":hip,"planted":false,"swing":false,"age":0.0})
    return true

func remove_pair() -> bool:
    if legs.size()<=4:return false
    legs.resize(legs.size()-2)
    support_count=0
    for l in legs:
        if l.planted:support_count+=1
    return true

func scale_reach(scale: float) -> void:
    upper=14*scale
    lower=14*scale
    max_reach=27*scale
    rest_height=18*scale
    stride=12*scale
    release_all()
