extends RefCounted
## Optional wall traversal. Input drives the body; contacts constrain the motor.
## Only reachable vertical faces of static rectangles are accepted.
var enabled: bool=true
var active: bool=false
var normal:=Vector2.ZERO
var face: Rect2
var wall_x: float=0
var cooldown: float=0
var attachments: int=0
var climb_speed: float=72
var separation: float=17

func detach() -> void:
    active=false
    cooldown=.25

func try_attach(body,axis: float,climb: float) -> bool:
    if not enabled or active or cooldown>0 or absf(climb)<.1:return false
    var p: Vector2=body.nodes[0].p
    var best: float=24
    for box in body.obstacles:
        if box.size.y<32:continue
        if p.y<box.position.y+2 or p.y>box.end.y-2:continue
        for side in [-1.0,1.0]:
            var x: float=box.position.x if side<0 else box.end.x
            var gap: float=(p.x-x)*side
            if gap<6 or gap>best or axis*side>.1:continue
            var target:=Vector2(x+side*.15,p.y)
            if not _clear(p,target,body.obstacles):continue
            best=gap
            face=box
            normal=Vector2(side,0)
            wall_x=x
            active=true
    if active:attachments+=1
    return active

func _clear(a: Vector2,b: Vector2,boxes: Array[Rect2]) -> bool:
    for i in range(1,9):
        var p: Vector2=a.lerp(b,float(i)/9)
        for box in boxes:
            if box.has_point(p):return false
    return true

func validate(body,axis: float,has_legs: bool) -> bool:
    if not active:return false
    var p: Vector2=body.nodes[0].p
    if not enabled or not has_legs or axis*normal.x>.1 or absf(p.x-wall_x)>34 or p.y>face.end.y+10:
        detach()
        return false
    return true

func drive(body,climb: float,support_count: int) -> void:
    if support_count==0:return
    for i in range(2):
        var n: Dictionary=body.nodes[i]
        var v: Vector2=n.v
        var p: Vector2=n.p
        var want_x: float=wall_x+normal.x*separation
        var ax: float=clampf((want_x-p.x)*155-v.x*23,-1200,1200)
        var ay: float=clampf((climb*climb_speed-v.y)*12-body.gravity.y,-1400,1000)
        body.force(i,Vector2(ax,ay)/float(n.inv))
    var front: Vector2=body.nodes[0].p
    var rear: Vector2=body.nodes[1].p
    var correction: Vector2=(Vector2(0,-16)-(front-rear))*60
    correction=correction.limit_length(700)
    body.force(0,correction)
    body.force(1,-correction)

func top_goal(body,climb: float) -> Dictionary:
    if not active or climb>=-.1 or face.size.x<24:return {}
    var p: Vector2=body.nodes[0].p
    if p.y>face.position.y+6 or p.y<face.position.y-16:return {}
    var goal:=Vector2(wall_x-normal.x*14,face.position.y-9)
    for box in body.obstacles:
        if box.grow(7).has_point(goal):return {}
    return {"target":goal,"side":-normal.x}
