extends RefCounted
const Seamless=preload("res://lab/motion_stylization/seamless_smear.gd")
const Sweep=preload("res://lab/motion_stylization/swept_body.gd")
var surface=Seamless.new()
var changed:bool=false
var extension:float=0.

func reset()->void:
    surface.reset()
    changed=false
    extension=0.

static func xy(v:Array)->Vector2:
    return Vector2(float(v[0]),float(v[1]))

static func move(p:Dictionary,k:String,d:Vector2)->void:
    p[k][0]+=d.x
    p[k][1]+=d.y

func build(parts:Array,drive,curved:bool,gain:float=1.)->Array:
    reset()
    if not drive.phase or drive.score<=.005 or drive.strength<=0. or drive.onset_tick<0:return parts
    var ids:Array=Sweep.indices(drive.anchor)
    if ids.is_empty():return parts
    var upper:int=ids[0]
    var lower:int=ids[1]
    if parts[upper].get("type")!="loft" or parts[lower].get("type")!="loft":return parts
    var a:Vector2=xy(parts[lower].a)
    var b:Vector2=xy(parts[lower].b)
    var axis:Vector2=(b-a).normalized()
    if axis.length_squared()<.01:return parts
    var normal:=Vector2(-axis.y,axis.x)
    var amount:float=sqrt(drive.score)*drive.strength
    var travel:Vector2=drive.displacement
    # Stretch the visual hinge away from current motion; retain shoulder/hip,
    # terminal wrist/ankle and hand/foot. Bound the lag by limb length.
    var max_lag:float=minf(8.*gain,a.distance_to(b)*minf(.65,.42*gain))
    var lag:Vector2=(-travel*amount*.52*gain).limit_length(max_lag)
    if lag.length_squared()<.015:return parts
    var out:Array=parts.duplicate(true)
    move(out[upper],"b",lag)
    move(out[lower],"a",lag)
    var p:Dictionary=out[lower]
    var start:Vector2=xy(p.a)
    var end:Vector2=xy(p.b)
    var axial:Vector2=(end-start).normalized()
    if axial.length_squared()<.01:return parts
    normal=Vector2(-axial.y,axial.x)
    # One contiguous loft, centerline shifted laterally via asymmetric widths
    # (right-left)/2. Keep total width approximately constant, never inflate
    # the whole limb. Preserve end sections and their material.
    var side:float=clampf((-travel).dot(normal)*amount*.30*gain,-minf(4.,3.*gain),minf(4.,3.*gain)) if curved else 0.
    var rows:Array=p.sections
    var sections:Array=[]
    var lo:float=float(rows[0][0])
    var hi:float=float(rows[-1][0])
    surface.outward=normal*(1. if side>=0. else -1.)
    for i in range(17):
        var t:float=lerpf(lo,hi,float(i)/16.)
        var row:Array=Seamless.section_at(rows,t)
        var u:float=clampf(t,0.,1.)
        var shift:float=side*sin(PI*u)
        # Keep the native loft radius validator satisfied and the cross
        # section connected to its original axis.
        shift=clampf(shift,-float(row[2])*.82,float(row[1])*.82)
        row[1]-=shift
        row[2]+=shift
        sections.append(row)
        if u>.12 and u<.90:
            var w:float=float(row[2] if side>=0. else row[1])
            surface.edge.append(start+(end-start)*t+surface.outward*w)
    p.sections=sections
    surface.owner=int(p.part_id)
    surface.changed=true
    surface.extension=lag.length()
    changed=true
    extension=lag.length()
    return out
