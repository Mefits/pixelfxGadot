extends "res://lab/spatial_lab/spatial_mocap_010.gd"
## E8, 24 source intervals (48 simulation ticks), exact periodic sampling.
## No combat integration; the inherited G20 direction-to-rig mapping is reused.
const PERIOD:int=48
const SOURCE_PERIOD:int=24
const FIXTURE="res://lab/spatial_lab/mocap/e8_directions.b64"
const FIXTURE_HASH="9b797636e2406531c84011f88914ea578641b70cf9f75e364f6667f5391c660f"
var rows:Array=[]
var means:Array[Vector3]=[]
var mode:int=1
var max_turn_shift:float=0.
var max_turn_toe_error:float=0.
var last_turn_shift:float=0.

func _init():
    super()
    data=Marshalls.base64_to_raw(FileAccess.get_file_as_string(FIXTURE).strip_edges())
    var h:=HashingContext.new()
    h.start(HashingContext.HASH_SHA256)
    h.update(data)
    assert(data.size()==25*STRIDE and h.finish().hex_encode()==FIXTURE_HASH)
    # Distribute the endpoint mismatch over the whole interval, rather
    # than abruptly blending the last few frames back to the first.
    for i in SOURCE_PERIOD:
        var row:Array[Vector3]=[]
        for k in 15:
            var v:Vector3=vec(i,k)-(vec(SOURCE_PERIOD,k)-vec(0,k))*float(i)/SOURCE_PERIOD
            row.append(v if k==0 else v.normalized())
        rows.append(row)
    for k in 15:
        var sum:=Vector3.ZERO
        for row in rows:sum+=Vector3(row[k])
        means.append(sum/float(SOURCE_PERIOD) if k==0 else sum.normalized())

func sample(tick:int,k:int)->Vector3:
    var f:float=float(posmod(tick,PERIOD))*.5
    var i:int=floori(f)
    var t:float=f-float(i)
    # Periodic Catmull-Rom: seam uses exactly the same neighboring samples.
    var a:Vector3=rows[posmod(i-1,SOURCE_PERIOD)][k]
    var b:Vector3=rows[i][k]
    var c:Vector3=rows[(i+1)%SOURCE_PERIOD][k]
    var d:Vector3=rows[(i+2)%SOURCE_PERIOD][k]
    var v:Vector3=b.cubic_interpolate(c,a,d,t)
    if mode>=2:v=means[k].lerp(v,.45)
    return v if k==0 else v.normalized()

func yaw_at(tick:int)->int:
    var v:Vector3=sample(tick,1)
    return roundi(atan2(v.x,v.z)*65536./TAU)

func setup(art:Dictionary)->void:
    super.setup(art)
    max_turn_shift=0.
    max_turn_toe_error=0.

func idle(tick:int)->Dictionary:
    var phase:int=posmod(tick,PERIOD)
    direct(rig,phase,pose)
    # Do not claim continuous ground contact in a bouncing source.
    # Only prevent toe-reference penetration by translating the whole rig.
    var low:float=maxf(Support.toe(rig,pose,"near").y,Support.toe(rig,pose,"far").y)
    translate(rig,Vector3(0.,-maxf(base_floor,low),0.))
    last_turn_shift=0.
    if mode!=3:return {"accepted":true}
    var c=FK.new()
    Entry.write_exact(c,Entry.sample(rig,pose))
    var turn:=Basis(Vector3.UP,deg_to_rad(-15.))
    var pivot:Vector3=rig.point3("hips")
    # Rotate girdles and upper body together around pelvis, preserving
    # lengths. Re-solve legs toward the unchanged C feet.
    for id in rig.ids_in_order():
        rig.joint_xyz[id]=pivot+turn*(rig.point3(id)-pivot)
        rig.joint_basis[id]=turn*Basis(rig.joint_basis[id])
    rig.yaw_units-=roundi(15.*65536./360.)
    var solver=Support.new()
    for side in Support.SIDES:
        solver.capture(c,pose,side,Support.FIXED)
        # Seed the pole from the unturned C pose but don't rotate it again.
        solver.contacts[side].pole_yaw=rig.yaw_units
    Entry.update_xy(rig)
    var solved=FK.new()
    var q:Dictionary=solver.resolve_evaluated(solved,rig,8.)
    if not q.accepted:return q
    last_turn_shift=Vector3(q.root_shift).length()
    max_turn_shift=maxf(max_turn_shift,last_turn_shift)
    for side in Support.SIDES:
        max_turn_toe_error=maxf(max_turn_toe_error,Support.toe(solved,pose,side).distance_to(Support.toe(c,pose,side)))
    Entry.write_exact(rig,Entry.sample(solved,pose))
    return q
