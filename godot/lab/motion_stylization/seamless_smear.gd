extends RefCounted
## A single analytic asymmetric loft replaces the distal limb. No added
## historical volumes, no duplicated hands/feet, no new native ABI.
var edge:PackedVector2Array=PackedVector2Array()
var outward:Vector2=Vector2.ZERO
var owner:int=-1
var changed:bool=false
var extension:float=0.

func reset()->void:
    edge.clear()
    outward=Vector2.ZERO
    owner=-1
    changed=false
    extension=0.

static func xy(v:Array)->Vector2:
    return Vector2(float(v[0]),float(v[1]))

static func section_at(rows:Array,u:float)->Array:
    for i in range(1,rows.size()):
        var a:Array=rows[i-1]
        var b:Array=rows[i]
        if u<=float(b[0]):
            var f:float=clampf((u-float(a[0]))/(float(b[0])-float(a[0])),0.,1.)
            return [u,lerpf(float(a[1]),float(b[1]),f),lerpf(float(a[2]),float(b[2]),f),lerpf(float(a[3]),float(b[3]),f),lerpf(float(a[4]),float(b[4]),f)]
    var end:Array=rows[-1].duplicate()
    end[0]=u
    return end

func build(parts:Array,sweep)->Array:
    reset()
    if sweep.envelope<=0. or sweep.power<=0. or sweep.history.size()<2 or sweep.current.size()!=3:return parts
    var ids:Array=sweep.indices(sweep.anchor)
    var index:int=int(ids[1])
    var lower:Dictionary=parts[index]
    if lower.get("type")!="loft":return parts
    var a:Vector2=xy(lower.a)
    var b:Vector2=xy(lower.b)
    var axis:Vector2=(b-a).normalized()
    if axis.length_squared()<.01:return parts
    var normal:=Vector2(-axis.y,axis.x)
    var arm:bool=sweep.anchor.begins_with("hand_")
    # Actual recent local displacement; use at most two preceding ticks.
    # Project earlier distal endpoints onto the current cross-section frame.
    var back:Vector2=Vector2.ZERO
    var old_a:Vector2=Vector2.ZERO
    for j in range(1,mini(3,sweep.history.size())):
        var old:Dictionary=sweep.history[sweep.history.size()-1-j].parts[1]
        var d:Vector2=xy(old.b)-b
        if d.length_squared()>back.length_squared():
            back=d
            old_a=xy(old.a)-a
    if back.length_squared()<.09:return parts
    var sign_side:float=1. if back.dot(normal)>=0. else -1.
    outward=normal*sign_side
    var intensity:float=minf(1.5,float(sweep.power))*float(sweep.envelope)
    var cap:float=8.5 if arm else 11.5
    var rows:Array=lower.sections
    var lo:float=float(rows[0][0])
    var hi:float=float(rows[-1][0])
    var new_rows:Array=[]
    # More axial samples, but one native primitive. Shared sections are
    # strictly ordered and continuous. Preserve both original cap rows.
    for i in range(17):
        var t:float=lerpf(lo,hi,float(i)/16.)
        var row:Array=section_at(rows,t)
        var u:float=clampf(t,0.,1.)
        var bell:float=pow(maxf(0.,sin(PI*u)),1.25)
        var historical:Vector2=old_a.lerp(back,u)
        var lateral:float=maxf(0.,historical.dot(outward))
        # Axial motion (straight punch) also creates a smaller asymmetric
        # silhouette rather than being invisible when lateral speed is zero.
        var axial:float=absf(historical.dot(axis))
        var extra:float=minf(cap,(lateral*1.35+axial*.50)*intensity)*bell
        var small:float=extra*.16
        if sign_side>0.:
            row[2]+=extra
            row[1]+=small
        else:
            row[1]+=extra
            row[2]+=small
        row[3]*=1.+.10*bell*intensity
        new_rows.append(row)
        extension=maxf(extension,extra)
        if u>.12 and u<.90:
            var width:float=float(row[2] if sign_side>0. else row[1])
            edge.append(a+(b-a)*t+outward*width)
    if extension<.18:
        reset()
        return parts
    var out:Array=parts.duplicate(true)
    out[index].sections=new_rows
    owner=int(lower.part_id)
    changed=true
    return out

func paint_surface(im:Image,result:Dictionary)->Image:
    if not changed or not result.has("part"):return im
    var ids:PackedInt32Array=result.part
    var w:int=im.get_width()
    var h:int=im.get_height()
    # A color strip on the actual visible surface, not a second sprite.
    # The native ownership mask excludes occluders and transparent pixels.
    var count:int=0
    var direction:Vector2=outward
    var x0:int=w
    var x1:int=0
    var y0:int=h
    var y1:int=0
    for p in edge:
        var q:Vector2=Vector2(240,219)+p*3.
        x0=mini(x0,floori(q.x)-6);x1=maxi(x1,ceili(q.x)+6)
        y0=mini(y0,floori(q.y)-6);y1=maxi(y1,ceili(q.y)+6)
    for y in range(maxi(0,y0),mini(h,y1+1)):
        for x in range(maxi(0,x0),mini(w,x1+1)):
            if ids[y*w+x]!=owner:continue
            var distance:int=0
            for k in range(1,5):
                var nx:int=x+roundi(direction.x*k)
                var ny:int=y+roundi(direction.y*k)
                if nx<0 or ny<0 or nx>=w or ny>=h:break
                if ids[ny*w+nx]!=owner:
                    if ids[ny*w+nx]==0:distance=k
                    break
            if distance==0:continue
            var original:Color=im.get_pixel(x,y)
            var tint:Color=Color(.98,.82,.51,original.a)
            im.set_pixel(x,y,original.lerp(tint,.72 if distance<=2 else .34))
            count+=1
    return im

func offset_segments()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if not changed or edge.size()<2:return out
    # A separate, narrow stroke beyond the actual deformed silhouette.
    for i in range(1,edge.size()):
        var u:float=float(i)/float(edge.size()-1)
        var offset:Vector2=outward*(2.3+1.1*sin(PI*u))
        out.append({"a":edge[i-1]+offset,"b":edge[i]+offset,"width":lerpf(.35,1.05,sin(PI*u)),"alpha":.72*sin(PI*u)+.18})
    return out
