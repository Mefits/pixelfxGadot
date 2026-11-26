extends RefCounted
## Independent fixed-step Verlet/PBD ribbon. All coordinates are rig units,
## y down, z toward camera. No authored animation of individual cloth nodes.
const ROWS=13
const DS=2.15
const WIDTH=2.8
const DT=1.0/120.0
var nodes:PackedVector3Array
var prev:PackedVector3Array
var edges:Array=[]
var pins:PackedVector3Array
var time:float=0.
var damping:float=.985
var bend:float=.18
var mass:float=1.
var collisions:Array=[]
func _init():
    nodes.resize(ROWS*2)
    prev.resize(ROWS*2)
    pins.resize(2)
    for i in ROWS:
        edges.append([2*i,2*i+1,WIDTH,1.])
        if i+1<ROWS:
            for j in 2:edges.append([2*i+j,2*(i+1)+j,DS,1.])
            edges.append([2*i,2*i+3,sqrt(DS*DS+WIDTH*WIDTH),.72])
            edges.append([2*i+1,2*i+2,sqrt(DS*DS+WIDTH*WIDTH),.72])
        if i+2<ROWS:
            for j in 2:edges.append([2*i+j,2*(i+2)+j,2.*DS,-1.])
func reset(anchor:Vector3)->void:
    time=0.
    set_anchor(anchor)
    for i in ROWS:
        for j in 2:
            nodes[2*i+j]=pins[j]+Vector3(DS*i,0.,0.)
    prev=nodes.duplicate()
func set_anchor(anchor:Vector3)->void:
    pins[0]=anchor+Vector3(0.,-WIDTH*.5,0.)
    pins[1]=anchor+Vector3(0.,WIDTH*.5,0.)
func pin()->void:
    for j in 2:nodes[j]=pins[j]
func collide(i:int)->void:
    # Simple conservative ellipsoid proxies; no self collision or
    # continuous collision detection. Push along the normalized local ray.
    for obj in collisions:
        var c:Vector3=obj[0]
        var radii:Vector3=obj[1]
        var v:Vector3=(nodes[i]-c)/radii
        var d:float=v.length()
        if d<1.:
            if d<.0001:v=Vector3(0,0,1)
            else:v/=d
            nodes[i]=c+v*radii
func step(wind:float,gust:bool)->void:
    time+=DT
    for i in range(2,nodes.size()):
        var p:Vector3=nodes[i]
        var velocity:Vector3=(p-prev[i])*damping
        var u:float=float(i/2)/float(ROWS-1)
        var wave:float=sin(time*9.-u*6.0)
        var w:float=wind*(1.+(.37*sin(time*4.1)+.18*sin(time*10.2) if gust else 0.))
        var force:=Vector3(w/mass,48.+absf(w)*.13*wave/mass,absf(w)*.24*sin(time*7.-u*5.+float(i%2)*.7)/mass)
        nodes[i]=p+velocity+force*DT*DT
        prev[i]=p
    for iteration in 10:
        pin()
        for edge in edges:
            var a:int=edge[0]
            var b:int=edge[1]
            var delta:Vector3=nodes[b]-nodes[a]
            var d:float=delta.length()
            if d<.00001:continue
            var stiff:float=bend if float(edge[3])<0. else float(edge[3])
            var wa:float=0. if a<2 else 1.
            var wb:float=0. if b<2 else 1.
            if wa+wb==0.:continue
            var correction:Vector3=delta*((d-float(edge[2]))/d)*stiff/(wa+wb)
            nodes[a]+=correction*wa
            nodes[b]-=correction*wb
        for i in range(2,nodes.size()):collide(i)
    pin()
func error()->float:
    var e:float=0.
    for edge in edges:
        if float(edge[3])!=1.:continue
        e=maxf(e,absf(nodes[edge[0]].distance_to(nodes[edge[1]])/float(edge[2])-1.))
    return e
func tip()->Vector3:
    return (nodes[-2]+nodes[-1])*.5
func arr(v:Vector3)->Array:return [v.x,v.y,v.z]
func triangles(parts:Array,material:int)->void:
    # Shared edge vertices, smoothed adjacent face normals, same Z-buffer as
    # anatomy. Render two-sided with normals facing the camera. No skinning.
    var faces:Array=[]
    var normals:PackedVector3Array
    normals.resize(nodes.size())
    for i in ROWS-1:
        faces.append([2*i,2*i+1,2*i+2])
        faces.append([2*i+1,2*i+3,2*i+2])
    for face in faces:
        var n:Vector3=(nodes[face[1]]-nodes[face[0]]).cross(nodes[face[2]]-nodes[face[0]])
        if n.z<0.:n=-n
        for j in face:normals[j]+=n
    for i in normals.size():
        normals[i]=normals[i].normalized() if normals[i].length_squared()>.000001 else Vector3(0,0,1)
    for f in faces:
        parts.append({"type":"triangle","a":arr(nodes[f[0]]),"b":arr(nodes[f[1]]),"c":arr(nodes[f[2]]),
            "na":arr(normals[f[0]]),"nb":arr(normals[f[1]]),"nc":arr(normals[f[2]]),
            "part_id":parts.size()+1,"material_id":material})
