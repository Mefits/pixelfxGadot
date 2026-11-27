extends RefCounted
const Body=preload("res://lab/body_ankle_069.gd")
const Landing=preload("res://lab/impact_landing_095.gd")
const Solver=preload("res://lab/ragdoll_reference_099.gd")
const Leg=preload("res://lab/leg_constraints_082.gd")
const FIX="res://tests/fixtures/body_raster/full_058/combo052a2_B.json"
const N:int=300
const H:float=1./120.
const G:float=180.
# All three get an identical horizontal impulse, at the actual chest point.
# No assigned Y velocity or whole-body spin. Art units, not measured newtons.
static func make_model():
    var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var verified:bool=false
    for f in fixture.clips:
        if f.clip=="combo052a2_B":verified=FileAccess.get_sha256(FIX)==f.sha256
    assert(verified,"frozen guard SHA")
    var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIX)).payload.clip.keys[0].pose
    var rig=Body.make_rig()
    var entry:Dictionary=Landing.new(rig,source,2).base.duplicate(true)
    var m=Solver.new(rig,entry,entry,0.,false,Vector2.ZERO,0.,0,28)
    var bottom:float=-INF
    for b in m.bodies:
        for s in b.samples:
            bottom=maxf(bottom,(m.pivot(b)+Vector2(s[0]).rotated(b.a)).y+float(s[1]))
        var id:String=b.id
        if id.begins_with("thigh_"):
            b.lo=maxf(b.lo,deg_to_rad(-105.+Leg.rest(id.trim_prefix("thigh_"))))
        # Same wide soft bands, residual tone and bounded target motor.
        var band:=Vector2(float(b.lo),float(b.hi))
        var k:float=0.
        var damp:float=5.
        var cap:float=35.
        if id.begins_with("thigh_"):
            var rest:float=Leg.rest(id.trim_prefix("thigh_"))
            band=Vector2(-60.+rest,32.+rest)*PI/180.
            k=120.
            damp=12.
            cap=160.
        elif id=="chest":
            band=Vector2(-20,30)*PI/180.
            k=120.
            damp=10.
            cap=140.
        elif id=="head":
            band=Vector2(-25,30)*PI/180.
            k=50.
            damp=10.
            cap=55.
        elif id.begins_with("knee_"):
            var rest:float=Leg.rest(id.trim_prefix("knee_"))
            band=Vector2(-2.*rest,100.-2.*rest)*PI/180.
            k=40.
            damp=12.
            cap=65.
        b["band"]=band
        b["k"]=k
        b["damping"]=damp
        b["cap"]=cap
        b.goal=clampf(b.goal,b.lo,b.hi)
    m.floor_y=bottom
    return m

static func event(m)->Dictionary:
    var mass:float=0.
    for b in m.bodies:mass+=float(b.mass)
    var idx:int=int(m.ids.chest)
    var b:Dictionary=m.bodies[idx]
    # contact slightly above the chest segment COM, still inside its proxy.
    var point:Vector2=Vector2(b.p)+Vector2(2.,-2.).rotated(float(b.a))
    return {"idx":idx,"point":point,"impulse":Vector2(-mass*90.,0.)}

static func control(a:Dictionary,b:Dictionary,step:int)->float:
    var relative:float=wrapf(float(b.a)-float(a.a),-PI,PI)
    var speed:float=float(b.w)-float(a.w)
    var effective:float=1./(float(a.ii)+float(b.ii))
    var blend:float=1.-smoothstep(.06,.24,float(step)*H)
    var error:float=wrapf(float(b.goal)-relative,-PI,PI)
    var active:float=clampf((360.*error-24.*speed)*effective,-480.,480.)
    var band:Vector2=b.band
    var excess:float=relative-clampf(relative,band.x,band.y)
    var residual:float=clampf(-float(b.k)*excess-float(b.damping)*effective*speed,-float(b.cap),float(b.cap))
    # Common compliant stop; A/C also have native hard angular limits.
    var outside:float=relative-clampf(relative,float(b.lo),float(b.hi))
    var stop:float=0.
    if absf(outside)>.00001:
        stop=clampf(-2400.*outside-28.*effective*speed,-1800.,1800.)
    return (lerpf(residual,active,blend)+stop)*H

static func state(m)->Array:
    var row:Array=[]
    for b in m.bodies:
        row.append([b.p.x,b.p.y,b.a,b.v.x,b.v.y,b.w])
    return row

static func load_state(m,row:Array)->void:
    for i in m.bodies.size():
        var b:Dictionary=m.bodies[i]
        var v:Array=row[i]
        b.p=Vector2(v[0],v[1])
        b.a=float(v[2])
        b.v=Vector2(v[3],v[4])
        b.w=float(v[5])

static func specification(m)->String:
    var lines:=PackedStringArray()
    var e:Dictionary=event(m)
    lines.append("%d %d %.9f %d %.9f %.9f %.9f %.9f"%[m.bodies.size(),N,m.floor_y,e.idx,e.point.x,e.point.y,e.impulse.x,e.impulse.y])
    for b in m.bodies:
        var vals:Array=[b.parent,b.p.x,b.p.y,b.a,b.mass,1./float(b.ii),b.com.x,b.com.y,b.offset.x,b.offset.y,b.lo,b.hi,b.goal,b.band.x,b.band.y,b.k,b.damping,b.cap,b.samples.size()]
        var fields:=PackedStringArray()
        for v in vals:fields.append(str(v))
        lines.append(" ".join(fields))
        for s in b.samples:lines.append("%.9f %.9f %.9f"%[s[0].x,s[0].y,s[1]])
    return "\n".join(lines)+"\n"

static func export_spec(m,path:String)->void:
    var f=FileAccess.open(path,FileAccess.WRITE)
    f.store_string(specification(m))
    f.close()

static func validate(m)->Dictionary:
    var anchor:float=0.
    var floor_error:float=0.
    var limit_error:float=0.
    var speed:float=0.
    var contacts:int=0
    for b in m.bodies:
        assert(Vector2(b.p).is_finite() and Vector2(b.v).is_finite() and is_finite(b.a) and is_finite(b.w),"nonfinite backend")
        speed=maxf(speed,Vector2(b.v).length()+absf(float(b.w))*2.)
        if int(b.parent)>=0:
            var a:Dictionary=m.bodies[b.parent]
            anchor=maxf(anchor,m.pivot(b).distance_to(m.pivot(a)+Vector2(b.offset).rotated(a.a)))
            var relative:float=wrapf(float(b.a)-float(a.a),-PI,PI)
            limit_error=maxf(limit_error,absf(relative-clampf(relative,b.lo,b.hi)))
        var close:bool=false
        for s in b.samples:
            var depth:float=(m.pivot(b)+Vector2(s[0]).rotated(b.a)).y+float(s[1])-m.floor_y
            floor_error=maxf(floor_error,depth)
            if depth>=-.25:close=true
        if close:contacts+=1
    return {"anchor":anchor,"penetration":floor_error,"angle_error_deg":rad_to_deg(limit_error),"speed":speed,"near_floor":contacts}
