extends RefCounted
## Reusable position-based particle body. World coordinates in art pixels.
## Fixed 120 Hz substeps, inverse-mass weighted distance constraints,
## circle vs static AABB contacts. No rendering or input dependencies.
const DT: float=1.0/120.0
var nodes: Array[Dictionary]=[]
var links: Array[Dictionary]=[]
var ids: Dictionary={}
var obstacles: Array[Rect2]=[]
var gravity:=Vector2(0,340)
var damping: float=0.8
var friction: float=0.25
var iterations: int=10
var accumulator: float=0
var steps: int=0
var max_error: float=0
var dropped_time: float=0

func add_point(id: String,p: Vector2,radius: float,mass: float) -> int:
    if ids.has(id) or radius<=0 or mass<=0 or not p.is_finite():
        return -1
    var i: int=nodes.size()
    ids[id]=i
    nodes.append({"id":id,"p":p,"v":Vector2.ZERO,"old":p,"r":radius,"inv":1.0/mass,"force":Vector2.ZERO,"normal":Vector2.ZERO,"normal_push":0.0,"ground":false,"wall":false})
    return i

func connect_points(a: int,b: int,length: float,compliance: float=0.0) -> bool:
    if a<0 or b<0 or a>=nodes.size() or b>=nodes.size() or a==b or length<=0:
        return false
    links.append({"a":a,"b":b,"length":length,"compliance":maxf(0,compliance),"lambda":0.0})
    return true

func point(id: String) -> Vector2:
    return nodes[ids[id]].p if ids.has(id) else Vector2.ZERO

func impulse(i: int,dv: Vector2) -> void:
    if i>=0 and i<nodes.size():
        nodes[i].v+=dv

func force(i: int,f: Vector2) -> void:
    if i>=0 and i<nodes.size():
        nodes[i].force+=f

func advance(dt: float,before_step: Callable=Callable()) -> void:
    if not is_finite(dt) or dt<0:return
    var accepted: float=minf(dt,.1)
    dropped_time+=dt-accepted
    accumulator+=accepted
    while accumulator+1e-9>=DT:
        if before_step.is_valid():before_step.call(DT)
        step()
        accumulator=maxf(0,accumulator-DT)

func step() -> void:
    for n in nodes:
        n.old=n.p
        n.normal=Vector2.ZERO
        n.normal_push=0.0
        n.ground=false
        n.wall=false
        n.v=(Vector2(n.v)+(gravity+Vector2(n.force)*float(n.inv))*DT)*exp(-damping*DT)
        n.force=Vector2.ZERO
        # Bound velocity to keep substep displacement below main body radius.
        n.v=Vector2(n.v).limit_length(420)
        n.p+=Vector2(n.v)*DT
    for l in links:l["lambda"]=0.0
    for _i in range(iterations):
        for l in links:_distance(l)
        for n in nodes:
            for box in obstacles:_contact(n,box)
    max_error=0
    for l in links:
        max_error=maxf(max_error,absf(Vector2(nodes[l.a].p).distance_to(nodes[l.b].p)-float(l.length)))
    for n in nodes:
        n.v=(Vector2(n.p)-Vector2(n.old))/DT
        var normal: Vector2=n.normal
        if normal.length_squared()>.00001:
            normal=normal.normalized()
            var vn: float=Vector2(n.v).dot(normal)
            if vn<0:n.v-=normal*vn
            var tangent: Vector2=Vector2(n.v)-normal*Vector2(n.v).dot(normal)
            # Coulomb-style limit from normal positional correction, not
            # a percentage of speed every tick. Preserve floor mobility.
            var speed: float=tangent.length()
            if speed>.00001:
                var loss: float=minf(speed,friction*float(n.normal_push)/DT)
                n.v-=tangent*(loss/speed)
    steps+=1

func _distance(l: Dictionary) -> void:
    var a: Dictionary=nodes[l.a]
    var b: Dictionary=nodes[l.b]
    var d: Vector2=Vector2(b.p)-Vector2(a.p)
    var dist: float=d.length()
    var axis: Vector2=d/dist if dist>.00001 else Vector2.RIGHT
    var alpha: float=float(l.compliance)/(DT*DT)
    var dl: float=-(dist-float(l.length)+alpha*float(l["lambda"]))/(float(a.inv)+float(b.inv)+alpha)
    l["lambda"]+=dl
    a.p-=axis*dl*float(a.inv)
    b.p+=axis*dl*float(b.inv)

func _contact(n: Dictionary,box: Rect2) -> void:
    var p: Vector2=n.p
    var r: float=n.r
    var near: Vector2=p.clamp(box.position,box.end)
    var diff: Vector2=p-near
    var dist: float=diff.length()
    var normal:=Vector2.ZERO
    var push: float=0
    if p.x>=box.position.x and p.x<=box.end.x and p.y>=box.position.y and p.y<=box.end.y:
        var distances: Array[float]=[p.x-box.position.x,box.end.x-p.x,p.y-box.position.y,box.end.y-p.y]
        var side: int=distances.find(distances.min())
        normal=[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN][side]
        push=distances[side]+r
    elif dist<r and dist>.000001:
        normal=diff/dist
        push=r-dist
    else:return
    n.p+=normal*push
    n.normal+=normal
    n.normal_push+=push
    if normal.y<-.55:n.ground=true
    if absf(normal.x)>.7:n.wall=true

func penetration() -> float:
    var worst: float=0
    for n in nodes:
        for box in obstacles:
            var p: Vector2=n.p
            var d: float=p.distance_to(p.clamp(box.position,box.end))
            if box.has_point(p):
                worst=maxf(worst,float(n.r))
            else:worst=maxf(worst,float(n.r)-d)
    return worst

func center_of_mass() -> Vector2:
    var sum:=Vector2.ZERO
    var total: float=0
    for n in nodes:
        var m: float=1.0/float(n.inv)
        sum+=Vector2(n.p)*m
        total+=m
    return sum/maxf(total,.00001)

func finite() -> bool:
    for n in nodes:
        if not Vector2(n.p).is_finite() or not Vector2(n.v).is_finite():return false
    return true
