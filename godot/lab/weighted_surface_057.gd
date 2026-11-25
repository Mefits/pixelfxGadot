extends RefCounted
# Generic indexed 2.5D bind mesh: vertex positions/normals and two influences.
# FK remains external. Only explicit joint rows receive a bounded correction.
var vertices:Array=[]
var faces:Array=[]
var bind_points:Dictionary={}
var bind_rot:Dictionary={}
func add(p:Vector2,z:float,n:Vector3,b0:String,b1:String,w:float,pivot:String="")->int:
    vertices.append({"p":p,"z":z,"n":n.normalized(),"b0":b0,"b1":b1,"w":w,"pivot":pivot})
    return vertices.size()-1
func tri(a:int,b:int,c:int,m:int)->void:
    faces.append([a,b,c,m])
func strip(a:Array,b:Array,m:int)->void:
    assert(a.size()==b.size())
    for j in a.size()-1:
        tri(a[j],a[j+1],b[j+1],m)
        tri(a[j],b[j+1],b[j],m)
func fan(boundary:Array,center:int,m:int)->void:
    for j in boundary.size():
        tri(boundary[j],boundary[(j+1)%boundary.size()],center,m)
func row(at:Vector2,across:Vector2,w:float,z:float,depth:float,b0:String,b1:String,mix:float,pivot:String="")->Array:
    var out:Array=[]
    for i in 5:
        var s:float=float(i-2)*.5
        var ridge:float=sqrt(maxf(0,1-s*s))
        var normal:=Vector3(across.x*s*.72,across.y*s*.72,.72+ridge*.28)
        out.append(add(at+across*w*s,z+depth*ridge,normal,b0,b1,mix,pivot))
    return out
func edge(a:int,b:int,b0:String,b1:String,w:float)->Array:
    var out:Array=[a]
    var x:Dictionary=vertices[a]
    var y:Dictionary=vertices[b]
    for i in range(1,4):
        var t:float=float(i)*.25
        out.append(add(x.p.lerp(y.p,t),lerpf(x.z,y.z,t),x.n.lerp(y.n,t),b0,b1,w))
    out.append(b)
    return out
func mapped(id:String,p:Vector2,q:Dictionary,r:Dictionary)->Vector2:
    return Vector2(q[id])+(p-Vector2(bind_points[id])).rotated(float(r[id])-float(bind_rot[id]))
func deform(q:Dictionary,r:Dictionary,correct:bool)->Array:
    var out:Array=[]
    for a in vertices:
        var p:Vector2=a.p
        var w:float=a.w
        var d0:float=float(r[a.b0])-float(bind_rot[a.b0])
        var d1:float=float(r[a.b1])-float(bind_rot[a.b1])
        var u:Vector2=mapped(a.b0,p,q,r)
        var v:Vector2=mapped(a.b1,p,q,r)
        var pos:Vector2=u.lerp(v,w)
        # Shared-pivot local rotation blend. Preserve part of transverse
        # width instead of allowing opposite rotations to cancel.
        var c:Vector2=Vector2(cos(d0),sin(d0))*(1-w)+Vector2(cos(d1),sin(d1))*w
        var gain:float=1.0
        if correct and not String(a.pivot).is_empty():
            gain=minf(1.45,1.0/maxf(.01,c.length()))
            var pivot:Vector2=q[a.pivot]
            pos=pivot+(pos-pivot)*gain
        var xy:=Vector2(a.n.x,a.n.y)
        var n2:Vector2=xy.rotated(d0).lerp(xy.rotated(d1),w)*gain
        var n:=Vector3(n2.x,n2.y,a.n.z).normalized()
        out.append({"p":[pos.x,pos.y,a.z],"n":[n.x,n.y,n.z]})
    return out
func emit(deformed:Array)->Array:
    var out:Array=[]
    for f in faces:
        var a:Dictionary=deformed[f[0]]
        var b:Dictionary=deformed[f[1]]
        var c:Dictionary=deformed[f[2]]
        out.append({"type":"triangle","a":a.p,"b":b.p,"c":c.p,"na":a.n,"nb":b.n,"nc":c.n,"part_id":100+f[3],"material_id":f[3]})
    return out
func audit(deformed:Array)->Dictionary:
    var flip:int=0
    var collapsed:int=0
    var stretch:float=0.0
    for f in faces:
        var a:Vector2=vertices[f[0]].p
        var b:Vector2=vertices[f[1]].p
        var c:Vector2=vertices[f[2]].p
        var x:=Vector2(deformed[f[0]].p[0],deformed[f[0]].p[1])
        var y:=Vector2(deformed[f[1]].p[0],deformed[f[1]].p[1])
        var z:=Vector2(deformed[f[2]].p[0],deformed[f[2]].p[1])
        var before:float=(b-a).cross(c-a)
        var after:float=(y-x).cross(z-x)
        if absf(before)>.001:
            if before*after<0:flip+=1
            if absf(after)<absf(before)*.1:collapsed+=1
        for e in [[a,b,x,y],[b,c,y,z],[c,a,z,x]]:
            var len:float=e[0].distance_to(e[1])
            if len>.1:stretch=maxf(stretch,e[2].distance_to(e[3])/len)
    return {"flipped":flip,"collapsed":collapsed,"max_edge_ratio":stretch}
func validate()->bool:
    if vertices.is_empty() or faces.is_empty():return false
    var edges:Dictionary={}
    for a in vertices:
        if not bind_points.has(a.b0) or not bind_points.has(a.b1) or a.w<0 or a.w>1:return false
    for f in faces:
        for i in 3:
            if f[i]<0 or f[i]>=vertices.size() or f[i]==f[(i+1)%3]:return false
            var k:Vector2i=Vector2i(mini(f[i],f[(i+1)%3]),maxi(f[i],f[(i+1)%3]))
            edges[k]=int(edges.get(k,0))+1
            if edges[k]>2:return false
    return true
