extends RefCounted
## Locomotion controller; physical body is independent of poses and skin.
const LIMBS=preload("res://addons/creature/limbs.gd")
var limbs=LIMBS.new()
var grip_age: float=0
var grip_side: float=1
var grip_cooldown: float=0
const BODY=preload("res://addons/creature/physical_body.gd")
var body=BODY.new()
var direction: float=1
var input_axis: float=0
var jump_requested: bool=false
var coyote: float=0
var jump_cooldown: float=0
var grip: bool=false
var grip_index: int=-1
var grip_target:=Vector2.ZERO
var grip_radius: float=20
var acceleration: float=680
var max_speed: float=94
var jump_speed: float=146
var tail_count: int=5
var mass_scale: float=1
var grounded: bool=false
var jump_count: int=0
var grip_count: int=0

func _init(at: Vector2,boxes: Array[Rect2],tail: int=5,mass: float=1,with_limbs: bool=true) -> void:
    tail_count=clampi(tail,0,12)
    mass_scale=clampf(mass,.5,3)
    body.obstacles.assign(boxes)
    body.add_point("front",at,7,1.4*mass_scale)
    body.add_point("rear",at+Vector2(-16,2),7,1.8*mass_scale)
    body.connect_points(0,1,sqrt(260.0),.000001)
    var last: int=1
    var p: Vector2=body.nodes[last].p
    for i in range(tail_count):
        var r: float=maxf(2.0,5.0-i*.4)
        var length: float=maxf(5,9-i*.35)
        p+=Vector2(-length,0)
        var index: int=body.add_point("tail_%d"%i,p,r,maxf(.12,.5-i*.035)*mass_scale)
        body.connect_points(last,index,length,.000006)
        last=index
    limbs.enabled=with_limbs
    limbs.setup(body)

func advance(dt: float,axis: float,jump: bool,_legacy_grab: bool=false) -> void:
    input_axis=clampf(axis,-1,1)
    if jump:jump_requested=true
    body.advance(dt,_control)
    limbs.update_geometry(body,dt,direction)

func _control(dt: float) -> void:
    grip_cooldown=maxf(0,grip_cooldown-dt)
    limbs.step(body,dt,input_axis,direction,jump_cooldown<=0 and grip_index<0 and not jump_requested)
    grounded=body.nodes[0].ground or body.nodes[1].ground or limbs.support_count>0
    coyote=.09 if grounded else maxf(0,coyote-dt)
    jump_cooldown=maxf(0,jump_cooldown-dt)
    if absf(input_axis)>.05:direction=signf(input_axis)
    if grip_index<0 and grip_cooldown<=0 and absf(input_axis)>.1:
        _find_grip()
    if grip_index>=0:
        grip_age+=dt
        var p: Vector2=body.nodes[0].p
        var rear: Vector2=body.nodes[1].p
        if input_axis*grip_side<-.1 or grip_age>.75 or p.distance_to(grip_target)>44 or (rear.y<=grip_target.y+3 and (rear.x-grip_target.x)*grip_side>=-12):
            grip_index=-1
            grip_cooldown=.25
        else:
            # First lift clear of the corner, then pull forward. No teleport.
            var goal: Vector2=grip_target
            if p.y>grip_target.y+2:goal.x=p.x
            var v: Vector2=body.nodes[0].v
            var accel: Vector2=((goal-p)*220-v*20).limit_length(2200)
            body.force(0,(accel-body.gravity)/float(body.nodes[0].inv))
            body.force(1,Vector2(0,-700)/float(body.nodes[1].inv))
    if jump_requested:
        if (coyote>0 or grip_index>=0) and jump_cooldown<=0:
            for i in range(body.nodes.size()):
                body.impulse(i,Vector2(input_axis*16,-jump_speed*(1.0 if i<2 else .66)/sqrt(mass_scale)))
            grip_index=-1
            grip_cooldown=.24
            limbs.release_all()
            coyote=0
            jump_cooldown=.20
            jump_count+=1
        jump_requested=false
    for i in range(2):
        var n: Dictionary=body.nodes[i]
        var target: float=input_axis*max_speed
        var power: float=acceleration*(1.0 if grounded else .48)
        var ax: float=clampf((target-float(n.v.x))*9,-power,power)
        body.force(i,Vector2(ax/float(n.inv),0))
    # A limited muscular orientation force steers the front/rear axis.
    # It is not a transform animation: external contacts can override it.
    var front: Vector2=body.nodes[0].p
    var rear: Vector2=body.nodes[1].p
    var goal:=Vector2(direction*16,-2)
    var correction: Vector2=(goal-(front-rear))*30
    correction=correction.limit_length(360)
    body.force(0,correction)
    body.force(1,-correction)
    # Automatic pull is limited to reachable top corners in the movement direction.

func _find_grip() -> void:
    var best: float=grip_radius
    var front: Vector2=body.nodes[0].p
    var sign0: float=signf(input_axis)
    for box in body.obstacles:
        if box.size.x<24:continue
        var edge: float=box.position.x if sign0>0 else box.end.x
        var gap: float=(edge-front.x)*sign0
        var dy: float=front.y-box.position.y
        # Never climb a wall from its base: the head must reach the upper edge.
        if gap<0 or gap>grip_radius or dy< -12 or dy>13:continue
        var d: float=front.distance_to(Vector2(edge,box.position.y))
        var goal:=Vector2(edge+sign0*14,box.position.y-9)
        if d>=best:continue
        var clear: bool=true
        for other in body.obstacles:
            if other.grow(7).has_point(goal):clear=false;break
        if not clear:continue
        best=d
        grip_target=goal
        grip_side=sign0
        grip_index=0
    if grip_index>=0:
        grip_count+=1
        grip_age=0
        limbs.release_all()
