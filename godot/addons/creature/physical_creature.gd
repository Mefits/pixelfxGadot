extends RefCounted
## Locomotion controller; physical body is independent of poses and skin.
const SPECIAL=preload("res://addons/creature/physical_ability_runtime.gd")
var special=SPECIAL.new()
const ANATOMY=preload("res://addons/creature/anatomy.gd")
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
var acceleration: float=1050
var max_speed: float=126
var jump_speed: float=230
var jump_buffer: float=0
var jump_held: bool=true
var jump_cut: bool=false
var airborne_jump: bool=false
var air_time: float=0
var landing_time: float=0
var landing_strength: float=0
var landing_count: int=0
var wall_push_time: float=0
var wall_push_side: float=0
var motion_state: String="air"
var contact_polish: bool=true
var smooth_motion: bool=true
var anatomy:Dictionary={}
var branches:Array=[]
var tail_start:int=2
var upright:bool=false
var tail_count: int=2
var mass_scale: float=1
var grounded: bool=false
var jump_count: int=0
var grip_count: int=0

func _init(at: Vector2,boxes: Array[Rect2],tail: int=2,mass: float=1,with_limbs: bool=true,initial_direction: float=1,profile:Dictionary={}) -> void:
    direction=-1.0 if initial_direction<0 else 1.0
    tail_count=clampi(tail,0,12)
    mass_scale=clampf(mass,.5,3)
    anatomy=ANATOMY.normalize(profile) if ANATOMY.valid(profile) else ANATOMY.normalize({"tail":tail_count,"mass":mass_scale,"limbs":with_limbs})
    tail_count=int(anatomy.tail)
    mass_scale=float(anatomy.mass)
    upright=anatomy.type=="biped"
    max_speed=float(anatomy.speed)
    jump_speed=float(anatomy.jump)
    body.obstacles.assign(boxes)
    var trunk:float=float(anatomy.trunk)
    var offset:Vector2=Vector2(0,trunk) if upright else Vector2(-16*direction,2).normalized()*trunk
    body.add_point("front",at,7,1.4*mass_scale)
    body.add_point("rear",at+offset,7,1.8*mass_scale)
    body.connect_points(0,1,trunk,.000001)
    for branch in range(int(anatomy.tentacles)):
        var parent:int=0
        var chain:Array=[0]
        var pos:Vector2=at
        var axis:Vector2=Vector2(direction*(.6 if branch%2==0 else -.6),-1).normalized()
        for j in range(int(anatomy.tentacle_segments)):
            var length:float=float(anatomy.tentacle_length)
            pos+=axis*length
            var index:int=body.add_point("tentacle_%d_%d"%[branch,j],pos,maxf(1.5,3-j*.25),.14*mass_scale)
            body.connect_points(parent,index,length,.000012)
            chain.append(index)
            parent=index
        branches.append(chain)
    tail_start=body.nodes.size()
    var last: int=1
    var p: Vector2=body.nodes[last].p
    for i in range(tail_count):
        var r: float=maxf(2.0,4.0-i*.4)
        var length: float=maxf(5,7-i*.25)
        p+=Vector2(-length*direction,0)
        var index: int=body.add_point("tail_%d"%i,p,r,maxf(.07,.24-i*.018)*mass_scale)
        body.connect_points(last,index,length,.000006)
        last=index
    limbs.enabled=bool(anatomy.limbs)
    limbs.min_legs=2 if upright else (0 if anatomy.type=="crawler" else 4)
    limbs.upright=upright
    limb_scale=float(anatomy.reach)
    limbs.scale_reach(limb_scale)
    limbs.setup(body,int(anatomy.leg_count))

func advance(dt: float,axis: float,jump: bool,_legacy_grab: bool=false,climb: float=0,strike: bool=false,held: bool=true) -> void:
    input_axis=clampf(axis,-1,1)
    climb_axis=clampf(climb,-1,1)
    jump_held=held
    if jump:
        jump_requested=true
        jump_buffer=.12
    if strike:attack_requested=true
    body.advance(dt,_control,_after_step)
    
func _after_step(dt: float) -> void:
    attack.after_step(body,limbs,dt)
    special.after(self,dt)
    limbs.update_geometry(body,dt,direction)
    if surface.active:motion_state="wall"
    elif grip_index>=0:motion_state="ledge"
    elif landing_time>0 and grounded:motion_state="landing"
    elif grounded:motion_state="run" if absf(input_axis)>.05 else "idle"
    else:motion_state="rise" if float(body.nodes[0].v.y)<-12 else "fall"

func _control(dt: float) -> void:
    if attack.active and (not limbs.enabled or surface.active or grip_index>=0):attack.cancel(limbs)
    if attack_requested:
        if not special.active and not surface.active and grip_index<0 and not attack.active:
            if absf(input_axis)>.05:direction=signf(input_axis)
            attack.begin(limbs,direction)
        attack_requested=false
    if not attack.active and not surface.active and grip_index<0 and absf(input_axis)>.05:
        direction=signf(input_axis)
    var intent: Dictionary=attack.sample(attack.time) if attack.active else {}
    landing_time=maxf(0,landing_time-dt)
    wall_push_time=maxf(0,wall_push_time-dt)
    limbs.contact_polish=contact_polish
    limbs.landing_offset=-landing_strength*clampf(landing_time/.22,0,1) if contact_polish and not attack.active else 0.0
    limbs.rear_height_offset=float(intent.get("rear",0))
    limbs.front_height_offset=-sin(float(intent.get("tilt",0)))*float(body.links[0].length)*.7 if attack.active else 0.0
    if smooth_motion and not attack.active and not surface.active and grip_index<0:
        var axis: Vector2=body.point("front")-body.point("rear")
        if not upright and axis.x*direction<8:
            limbs.front_height_offset=5
            limbs.rear_height_offset=-5
    grip_cooldown=maxf(0,grip_cooldown-dt)
    surface.cooldown=maxf(0,surface.cooldown-dt)
    jump_cooldown=maxf(0,jump_cooldown-dt)
    jump_buffer=maxf(0,jump_buffer-dt)
    jump_requested=jump_buffer>0
    if not special.active and not upright and grip_index<0 and limbs.enabled and jump_cooldown<=0 and not jump_requested and not attack.active:
        if surface.try_attach(body,input_axis,climb_axis):
            direction=-surface.normal.x
    if surface.validate(body,input_axis,limbs.enabled):
        limbs.step_wall(body,dt,climb_axis,surface.normal,surface.face)
        var top: Dictionary=surface.top_goal(body,climb_axis)
        if jump_requested:
            for i in range(body.nodes.size()):
                body.impulse(i,Vector2(surface.normal.x*115,-(jump_speed if smooth_motion else 146.0)*.8)/sqrt(mass_scale))
            wall_push_side=surface.normal.x
            wall_push_time=.17 if contact_polish else 0.0
            surface.detach()
            limbs.release_all()
            grounded=false
            jump_requested=false
            jump_buffer=0
            airborne_jump=true
            jump_cut=false
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
            air_time=0
            landing_time=0
            coyote=0
            wall_ticks+=1
            return
        else:
            surface.detach()
    # Evaluate support before consuming a buffered jump, not after disabling feet.
    var rising: bool=(float(body.nodes[0].v.y)+float(body.nodes[1].v.y))*.5 < -12
    var allow_feet: bool=jump_cooldown<=0 and grip_index<0 and (not airborne_jump or not rising)
    limbs.step(body,dt,input_axis,direction,allow_feet)
    grounded=body.nodes[0].ground or body.nodes[1].ground or limbs.support_count>0
    if grounded:
        var fall_speed: float=(float(body.nodes[0].v.y)+float(body.nodes[1].v.y))*.5
        if contact_polish and air_time>.10 and fall_speed>45 and grip_index<0:
            landing_count+=1
            landing_strength=clampf(fall_speed*.033,2,6)
            landing_time=.22
        air_time=0
    elif grip_index<0:air_time+=dt
    else:air_time=0
    if grounded and jump_cooldown<=0:airborne_jump=false
    coyote=.12 if grounded else maxf(0,coyote-dt)
    if attack.active:direction=attack.facing
    elif absf(input_axis)>.05:direction=signf(input_axis)
    if not special.active and not upright and not attack.active and grip_index<0 and grip_cooldown<=0 and absf(input_axis)>.1 and not jump_requested:
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
            var speed: float=(jump_speed if smooth_motion else 146.0)/pow(mass_scale,.35 if smooth_motion else .5)
            for i in range(body.nodes.size()):
                var n: Dictionary=body.nodes[i]
                var desired_y: float=-speed*(1.0 if i<2 else .86)
                body.impulse(i,Vector2(input_axis*18,desired_y-minf(0,float(n.v.y))))
            grip_index=-1
            landing_time=0
            grip_cooldown=.24
            limbs.release_all()
            coyote=0
            jump_cooldown=.18
            jump_count+=1
            jump_buffer=0
            airborne_jump=true
            jump_cut=false
            grounded=false
        jump_requested=false
    if smooth_motion and airborne_jump and not jump_held and not jump_cut:
        for i in range(body.nodes.size()):
            var vy: float=body.nodes[i].v.y
            if vy< -65:body.impulse(i,Vector2(0,vy*-.55))
        jump_cut=true
    for i in range(2):
        var n: Dictionary=body.nodes[i]
        var target: float=float(intent.get("speed",0))*direction if attack.active else input_axis*(max_speed if smooth_motion else 94.0)
        if contact_polish and wall_push_time>0 and not attack.active:
            target=wall_push_side*maxf(85,absf(target))
        var power: float=680*1.6*(1.0 if grounded else .48) if attack.active else (acceleration if smooth_motion else 680.0)*(1.0 if grounded else .65)
        var gain: float=9
        if smooth_motion and not attack.active:
            gain=18 if absf(input_axis)<.05 and grounded else (14 if grounded else 8)
            if grounded and absf(input_axis)<.05:power*=1.25
            if grounded and target*float(n.v.x)<0:power*=1.2
        var ax: float=clampf((target-float(n.v.x))*gain,-power,power)
        body.force(i,Vector2(ax/float(n.inv),0))
    # A limited muscular orientation force steers the front/rear axis.
    # It is not a transform animation: external contacts can override it.
    var front: Vector2=body.nodes[0].p
    var rear: Vector2=body.nodes[1].p
    var goal:Vector2=Vector2(0,-float(body.links[0].length)) if upright else Vector2(direction*16,-2).normalized()*float(body.links[0].length)
    if attack.active:
        var trunk: float=body.links[0].length
        var tilt: float=float(intent.tilt)
        goal=Vector2(direction*cos(tilt),sin(tilt))*trunk
    var correction: Vector2=(goal-(front-rear))*(115 if attack.active else 30)
    if smooth_motion and not attack.active:
        # Tangential torque remains effective even when the desired direction
        # is exactly opposite the current trunk. Radial forces cannot turn it.
        var axis: Vector2=(front-rear).normalized()
        var tangent:=Vector2(-axis.y,axis.x)
        var target_angle: float=goal.angle()
        var error: float=wrapf(target_angle-axis.angle(),-PI,PI)
        var relative: Vector2=Vector2(body.nodes[0].v)-Vector2(body.nodes[1].v)
        var torque: float=clampf(error*950-relative.dot(tangent)*12,-1550,1550)
        correction=tangent*torque
    correction=correction.limit_length(1100 if attack.active else (1550 if smooth_motion else 360))
    body.force(0,correction)
    body.force(1,-correction)
    # Soft tail muscles resist folding and damp relative velocity; no rigid animation.
    if smooth_motion:
        for i in range(tail_start,body.nodes.size()):
            var n: Dictionary=body.nodes[i]
            var parent_index:int=1 if i==tail_start else i-1
            var grandparent:int=0 if i<=tail_start+1 else i-2
            if i==tail_start+1:grandparent=1
            var parent: Dictionary=body.nodes[parent_index]
            var axis: Vector2=(Vector2(parent.p)-Vector2(body.nodes[grandparent].p)).normalized()
            var goal_tail: Vector2=Vector2(parent.p)+axis*float(body.links[i-1].length)
            var f: Vector2=((goal_tail-Vector2(n.p))*9-(Vector2(n.v)-Vector2(parent.v))*1.8).limit_length(26)
            body.force(i,f)
            body.force(parent_index,-f)
    # Branches are true collision-bearing chains with bounded muscular forces.
    for branch_index in range(branches.size()):
        var chain:Array=branches[branch_index]
        for j in range(1,chain.size()):
            var index:int=chain[j]
            var parent:int=chain[j-1]
            var axis:Vector2=Vector2(direction*(.65 if branch_index%2==0 else -.65),-.85).normalized()
            if j>1:axis=(Vector2(body.nodes[parent].p)-Vector2(body.nodes[chain[j-2]].p)).normalized()
            axis=axis.rotated(sin(float(body.steps)*.045+j*.8+branch_index)*.22)
            var goal_branch:Vector2=Vector2(body.nodes[parent].p)+axis*float(anatomy.tentacle_length)
            var force:Vector2=((goal_branch-Vector2(body.nodes[index].p))*19-(Vector2(body.nodes[index].v)-Vector2(body.nodes[parent].v))*2).limit_length(36)
            body.force(index,force)
            body.force(parent,-force)
    special.steer(self,dt)
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
    return not special.active and not attack.active and not surface.active and grip_index<0

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
        var last: int=1 if tail_count==0 else body.nodes.size()-1
        var anchor: Vector2=body.nodes[last].p
        var radius: float=maxf(2.0,4.0-tail_count*.4)
        var length: float=maxf(5,7-tail_count*.25)
        var prior:int=0 if tail_count==0 else (1 if tail_count==1 else last-1)
        var axis: Vector2=(anchor-Vector2(body.nodes[prior].p)).normalized()
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
    if not can_mutate() or upright:return false
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

func anatomy_snapshot()->Dictionary:
    var out:Dictionary=anatomy.duplicate(true)
    out.tail=tail_count
    out.mass=mass_scale
    out.limbs=limbs.enabled and not limbs.legs.is_empty()
    out.leg_count=limbs.legs.size()
    out.reach=limb_scale
    return out
