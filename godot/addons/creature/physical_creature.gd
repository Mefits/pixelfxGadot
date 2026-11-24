extends RefCounted
## Locomotion controller; physical body is independent of poses and skin.
const LIMBS=preload("res://addons/creature/limbs.gd")
var limbs=LIMBS.new()
const ATTACK=preload("res://addons/creature/hybrid_attack.gd")
var attack=ATTACK.new()
var attack_requested: bool=false
const SURFACE=preload("res://addons/creature/surface_motor.gd")
var surface=SURFACE.new()
var climb_axis: float=0
var wall_ticks: int=0
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
var tail_count: int=2
var mass_scale: float=1
var grounded: bool=false
var jump_count: int=0
var grip_count: int=0

func _init(at: Vector2,boxes: Array[Rect2],tail: int=2,mass: float=1,with_limbs: bool=true,initial_direction: float=1) -> void:
    direction=-1.0 if initial_direction<0 else 1.0
    tail_count=clampi(tail,0,12)
    mass_scale=clampf(mass,.5,3)
    body.obstacles.assign(boxes)
    body.add_point("front",at,7,1.4*mass_scale)
    body.add_point("rear",at+Vector2(-16*direction,2),7,1.8*mass_scale)
    body.connect_points(0,1,sqrt(260.0),.000001)
    var last: int=1
    var p: Vector2=body.nodes[last].p
    for i in range(tail_count):
        var r: float=maxf(2.0,4.0-i*.4)
        var length: float=maxf(5,7-i*.25)
        p+=Vector2(-length*direction,0)
        var index: int=body.add_point("tail_%d"%i,p,r,maxf(.07,.24-i*.018)*mass_scale)
        body.connect_points(last,index,length,.000006)
        last=index
    limbs.enabled=with_limbs
    limbs.setup(body)

func advance(dt: float,axis: float,jump: bool,_legacy_grab: bool=false,climb: float=0,strike: bool=false) -> void:
    input_axis=clampf(axis,-1,1)
    climb_axis=clampf(climb,-1,1)
    if jump:jump_requested=true
    if strike:attack_requested=true
    body.advance(dt,_control,_after_step)
    limbs.update_geometry(body,dt,direction)

func _after_step(dt: float) -> void:
    attack.after_step(body,limbs,dt)

func _control(dt: float) -> void:
    if attack.active and (not limbs.enabled or surface.active or grip_index>=0):attack.cancel(limbs)
    if attack_requested:
        if not surface.active and grip_index<0 and not attack.active:
            if absf(input_axis)>.05:direction=signf(input_axis)
            attack.begin(limbs,direction)
        attack_requested=false
    var intent: Dictionary=attack.sample(attack.time) if attack.active else {}
    limbs.rear_height_offset=float(intent.get("rear",0))
    limbs.front_height_offset=-sin(float(intent.get("tilt",0)))*float(body.links[0].length)*.7 if attack.active else 0.0
    grip_cooldown=maxf(0,grip_cooldown-dt)
    surface.cooldown=maxf(0,surface.cooldown-dt)
    jump_cooldown=maxf(0,jump_cooldown-dt)
    if grip_index<0 and limbs.enabled and jump_cooldown<=0 and not jump_requested and not attack.active:
        if surface.try_attach(body,input_axis,climb_axis):
            direction=-surface.normal.x
    if surface.validate(body,input_axis,limbs.enabled):
        limbs.step_wall(body,dt,climb_axis,surface.normal,surface.face)
        var top: Dictionary=surface.top_goal(body,climb_axis)
        if jump_requested:
            for i in range(body.nodes.size()):
                body.impulse(i,Vector2(surface.normal.x*115,-jump_speed*.8)/sqrt(mass_scale))
            surface.detach()
            limbs.release_all()
            jump_requested=false
            jump_cooldown=.24
            coyote=0
            jump_count+=1
            return
        if not top.is_empty():
            grip_target=top.target
            grip_side=top.side
            direction=grip_side
            grip_index=0
            grip_age=0
            grip_count+=1
            surface.detach()
            limbs.release_all()
        elif limbs.support_count>0:
            surface.drive(body,climb_axis,limbs.support_count)
            grounded=false
            coyote=0
            wall_ticks+=1
            return
        else:
            surface.detach()
    limbs.step(body,dt,input_axis,direction,jump_cooldown<=0 and grip_index<0 and not jump_requested)
    grounded=body.nodes[0].ground or body.nodes[1].ground or limbs.support_count>0
    coyote=.09 if grounded else maxf(0,coyote-dt)
    if attack.active:direction=attack.facing
    elif absf(input_axis)>.05:direction=signf(input_axis)
    if not attack.active and grip_index<0 and grip_cooldown<=0 and absf(input_axis)>.1:
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
        var target: float=float(intent.get("speed",0))*direction if attack.active else input_axis*max_speed
        var power: float=acceleration*(1.6 if attack.active else 1.0)*(1.0 if grounded else .48)
        var ax: float=clampf((target-float(n.v.x))*9,-power,power)
        body.force(i,Vector2(ax/float(n.inv),0))
    # A limited muscular orientation force steers the front/rear axis.
    # It is not a transform animation: external contacts can override it.
    var front: Vector2=body.nodes[0].p
    var rear: Vector2=body.nodes[1].p
    var goal:=Vector2(direction*16,-2)
    if attack.active:
        var trunk: float=body.links[0].length
        var tilt: float=float(intent.tilt)
        goal=Vector2(direction*cos(tilt),sin(tilt))*trunk
    var correction: Vector2=(goal-(front-rear))*(115 if attack.active else 30)
    correction=correction.limit_length(1100 if attack.active else 360)
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

var limb_scale: float=1
var mutations: int=0

func can_mutate() -> bool:
    return not attack.active and not surface.active and grip_index<0

func change_tail(delta: int) -> bool:
    if not can_mutate() or delta==0:return false
    if delta<0:
        if tail_count<=0:return false
        var n: Dictionary=body.nodes[-1]
        body.ids.erase(n.id)
        body.nodes.pop_back()
        body.links.pop_back()
        tail_count-=1
    else:
        if tail_count>=12:return false
        var last: int=body.nodes.size()-1
        var anchor: Vector2=body.nodes[last].p
        var radius: float=maxf(2.0,4.0-tail_count*.4)
        var length: float=maxf(5,7-tail_count*.25)
        var axis: Vector2=(anchor-Vector2(body.nodes[last-1].p)).normalized()
        if axis.length_squared()<.001:axis=Vector2(-direction,0)
        var point:=Vector2.ZERO
        var found: bool=false
        for angle in [0.0,-.45,.45,-.9,.9,-1.5,1.5,PI]:
            var candidate: Vector2=anchor+axis.rotated(angle)*length
            var clear: bool=true
            for box in body.obstacles:
                if candidate.distance_to(candidate.clamp(box.position,box.end))<radius+.05:clear=false;break
            if clear and not ATTACK.segment_blocked(anchor,candidate,body.obstacles):
                point=candidate
                found=true
                break
        if not found:return false
        var index: int=body.add_point("tail_%d"%tail_count,point,radius,maxf(.07,.24-tail_count*.018)*mass_scale)
        body.nodes[index].v=body.nodes[last].v
        body.connect_points(last,index,length,.000006)
        tail_count+=1
    mutations+=1
    return true

func change_mass(delta: float) -> bool:
    if not can_mutate():return false
    var next: float=clampf(mass_scale+delta,.5,3)
    if is_equal_approx(next,mass_scale):return false
    for n in body.nodes:
        n.inv=float(n.inv)*mass_scale/next
    mass_scale=next
    mutations+=1
    return true

func change_legs(add: bool) -> bool:
    if not can_mutate():return false
    var ok: bool=limbs.add_pair(body) if add else limbs.remove_pair()
    if ok:mutations+=1
    return ok

func change_reach(delta: float) -> bool:
    if not can_mutate():return false
    var next: float=clampf(limb_scale+delta,.75,1.5)
    if is_equal_approx(next,limb_scale):return false
    limb_scale=next
    limbs.scale_reach(next)
    mutations+=1
    return true
