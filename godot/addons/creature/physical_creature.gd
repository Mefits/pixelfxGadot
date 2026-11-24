extends RefCounted
## Locomotion controller; physical body is independent of poses and skin.
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
var grip_radius: float=12
var acceleration: float=680
var max_speed: float=94
var jump_speed: float=146
var tail_count: int=5
var mass_scale: float=1
var grounded: bool=false
var jump_count: int=0
var grip_count: int=0

func _init(at: Vector2,boxes: Array[Rect2],tail: int=5,mass: float=1) -> void:
    tail_count=clampi(tail,0,12)
    mass_scale=clampf(mass,.5,3)
    body.obstacles=boxes.duplicate()
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

func advance(dt: float,axis: float,jump: bool,grab: bool) -> void:
    input_axis=clampf(axis,-1,1)
    if jump:jump_requested=true
    grip=grab
    body.advance(dt,_control)

func _control(dt: float) -> void:
    grounded=body.nodes[0].ground or body.nodes[1].ground
    coyote=.09 if grounded else maxf(0,coyote-dt)
    jump_cooldown=maxf(0,jump_cooldown-dt)
    if absf(input_axis)>.05:direction=signf(input_axis)
    if not grip:grip_index=-1
    if grip and grip_index<0:
        _find_grip()
    if grip_index>=0:
        var p: Vector2=body.nodes[grip_index].p
        if p.distance_to(grip_target)>24:
            grip_index=-1
        else:
            # Compliant force, not teleport. The collision solver remains authoritative.
            var v: Vector2=body.nodes[grip_index].v
            body.force(grip_index,((grip_target-p)*210-v*17)/float(body.nodes[grip_index].inv))
    if jump_requested:
        if (coyote>0 or grip_index>=0) and jump_cooldown<=0:
            for i in range(body.nodes.size()):
                body.impulse(i,Vector2(input_axis*16,-jump_speed*(1.0 if i<2 else .66)/sqrt(mass_scale)))
            grip_index=-1
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
    # Raise the leading segment when pressing into a low wall while grounded.
    if grounded and absf(input_axis)>.1 and body.nodes[0].wall:
        body.force(0,Vector2(0,-750))

func _find_grip() -> void:
    var best: float=grip_radius
    var front: Vector2=body.nodes[0].p
    for box in body.obstacles:
        # Only top corners or vertical faces, not arbitrary points in empty air.
        for corner in [box.position,Vector2(box.end.x,box.position.y)]:
            var q: Vector2=corner+Vector2(0,-float(body.nodes[0].r))
            var d: float=front.distance_to(q)
            if d<best:
                best=d
                grip_target=q
                grip_index=0
    if grip_index>=0:grip_count+=1
