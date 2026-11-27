extends RefCounted
## Experimental authority bridge. Astra is sampled at 120 Hz; Box2D is
## authoritative for dynamic segments. No dynamic transform overwrite.
const Common=preload("res://lab/ragdoll_common_099c.gd")
const Asset=preload("res://lab/authoring/asset.gd")
const DT:float=1./120.
const GIRDLE=["shoulder_near","shoulder_far","thigh_near","thigh_far"]
var players:Array=[]
var models:Array=[]
var offsets:Array=[]
var rows:Array=[]
var world
var n:int=0
var tick:int=0
var release_tick:int=-1
var attacker_release_tick:int=-1
var attacker_release_error:float=0.
var contact_tick:int=-1
var contact_impulse:float=0.
var contacts:Array=[]
var release_error:float=0.
var track_error:float=0.
var pair:bool=false
var floor_y:float=0.

func lower(id:String)->bool:
    return id=="hips" or id.begins_with("thigh_") or id.begins_with("knee_") or id.begins_with("foot_")

func driven(c:int,i:int)->bool:
    return attacker_release_tick<0 if pair and c==0 else (release_tick<0 and lower(models[c].bodies[i].id))

func sample(c:int)->Array:
    var p=players[c]
    var m=models[c]
    var pose:Dictionary=p.final_pose
    m.rig.evaluate(pose)
    var travel:Vector2=Vector2(float(p.gait.travel)+float(offsets[c]),0.)
    var out:Array=[]
    for b in m.bodies:
        var a:float=m.rotation_for(b.id,pose,m.rig.rotations)
        var v:Vector2=m.rig.point(b.id)+Vector2(b.com).rotated(a)+travel
        out.append([v.x,v.y,a])
    return out

# The accepted 2.5D FK changes projected shoulder/hip offsets with turn.
# Keep the native revolute frame and the display rig consistent; freeze on release.
func sync_projection(c:int,native:bool)->bool:
    var m=models[c]
    for channel in ["shoulder_turn","pelvis_turn"]:
        m.template.angles[channel]=players[c].final_pose.angles.get(channel,0.)
    for id in GIRDLE:
        var i:int=m.ids[id]
        var offset:Vector2=m.rig.joints[m.rig.ids[id]].offset
        m.bodies[i].offset=offset
        if native and not world.set_joint_offset(c*n+i,offset):return false
    return true

func velocity(a:Array,b:Array)->Array:
    return [(b[0]-a[0])/DT,(b[1]-a[1])/DT,wrapf(float(b[2])-float(a[2]),-PI,PI)/DT]

func setup(two:bool=true)->bool:
    pair=two
    players.clear()
    models.clear()
    rows.clear()
    offsets=[0.,36.] if pair else [0.]
    tick=0
    release_tick=-1
    attacker_release_tick=-1
    attacker_release_error=0.
    contact_tick=-1
    contact_impulse=0.
    contacts.clear()
    release_error=0.
    track_error=0.
    var gait:Dictionary=Asset.read(Asset.DIR+"sprint.json")
    var jab:Dictionary=Asset.read(Asset.DIR+"jab.json")
    var first:Array=[]
    var prior:Array=[]
    floor_y=-INF
    for c in offsets.size():
        var p=Asset.ensemble(gait,[jab],120)
        players.append(p)
        models.append(Common.make_model())
        prior.append(sample(c))
        p.step({"speed":1.85 if c==0 else 1.})
        first.append(sample(c))
        if not sync_projection(c,false):return false
        var m=models[c]
        n=m.bodies.size()
        for i in n:
            var b:Dictionary=m.bodies[i]
            var r:Array=first[c][i]
            for shape in b.samples:
                var point:Vector2=Vector2(r[0],r[1])+(Vector2(shape[0])-Vector2(b.com)).rotated(r[2])
                floor_y=maxf(floor_y,point.y+float(shape[1]))
    # Flat shared floor; proxy envelope, not visual mesh collision.
    floor_y+=.15
    for m in models:m.floor_y=floor_y
    world=ClassDB.instantiate("MotionPhysics099D")
    if world==null:return false
    var spec:String=Common.specification(models[0])
    if pair:
        if not world.setup_pair(spec,16,1):return false
    elif not world.setup(spec,8,1,1):return false
    for c in offsets.size():
        for i in n:
            var r:Array=first[c][i]
            var v:Array=velocity(prior[c][i],r)
            var index:int=c*n+i
            if driven(c,i) and not world.set_kinematic(index,true):return false
            if not world.initialize_segment(index,Vector2(r[0],r[1]),r[2],Vector2(v[0],v[1]),v[2]):return false
    for c in offsets.size():
        if not sync_projection(c,true):return false
    rows=first
    return true

func release()->bool:
    if release_tick>=0:return false
    var c:int=1 if pair else 0
    var before:Array=world.state()
    for i in n:
        if lower(models[c].bodies[i].id):
            if not world.set_kinematic(c*n+i,false):return false
    var after:Array=world.state()
    for i in n:
        for k in 6:
            var d:float=absf(float(before[c*n+i][k])-float(after[c*n+i][k]))
            if k==2:d=absf(wrapf(float(before[c*n+i][k])-float(after[c*n+i][k]),-PI,PI))
            release_error=maxf(release_error,d)
    release_tick=tick
    return true

# Release the approaching body BEFORE impact, from actual native collision
# proxies, so the contact solver sees finite mass rather than an infinite motor.
func cross_gap()->float:
    var state:Array=world.state()
    var gap:float=INF
    for i in n:
        var a:Dictionary=models[0].bodies[i]
        var ra:Array=state[i]
        for j in n:
            var b:Dictionary=models[1].bodies[j]
            var rb:Array=state[n+j]
            for ca in a.samples:
                var pa:Vector2=Vector2(ra[0],ra[1])+(Vector2(ca[0])-Vector2(a.com)).rotated(ra[2])
                for cb in b.samples:
                    var pb:Vector2=Vector2(rb[0],rb[1])+(Vector2(cb[0])-Vector2(b.com)).rotated(rb[2])
                    gap=minf(gap,pa.distance_to(pb)-float(ca[1])-float(cb[1]))
    return gap

func release_attacker()->bool:
    var before:Array=world.state()
    for i in n:
        if not world.set_kinematic(i,false):return false
    var after:Array=world.state()
    for i in n:
        for k in 6:
            var d:float=absf(float(before[i][k])-float(after[i][k]))
            if k==2:d=absf(wrapf(float(before[i][k])-float(after[i][k]),-PI,PI))
            attacker_release_error=maxf(attacker_release_error,d)
    attacker_release_tick=tick
    return true

func step(commands:Array,force_release:bool=false)->bool:
    if pair and attacker_release_tick<0 and cross_gap()<2.5:
        if not release_attacker():return false
    if force_release and release_tick<0:
        if not release():return false
    var weights:=PackedFloat64Array()
    var targets:=PackedFloat64Array()
    weights.resize(n*offsets.size())
    targets.resize(weights.size())
    for c in offsets.size():
        if (pair and c==0 and attacker_release_tick<0) or ((not pair or c==1) and release_tick<0):
            players[c].step(commands[c])
            rows[c]=sample(c)
            if not sync_projection(c,true):return false
        for i in n:
            var idx:int=c*n+i
            var r:Array=rows[c][i]
            if driven(c,i):
                if not world.drive_segment(idx,Vector2(r[0],r[1]),r[2]):return false
            var b:Dictionary=models[c].bodies[i]
            var parent:int=b.parent
            var target:float=0. if parent<0 else wrapf(float(r[2])-float(rows[c][parent][2]),-PI,PI)
            if not driven(c,i):
                var released_at:int=attacker_release_tick if pair and c==0 else release_tick
                if released_at<0:
                    weights[idx]=.85
                else:
                    # Release authority progressively; retain bounded residual muscle tone.
                    var u:float=smoothstep(0.,.25,float(tick-released_at)*DT)
                    weights[idx]=lerpf(.65,.08,u)
                    target=lerpf(target,float(b.goal),u)
            targets[idx]=clampf(target,float(b.lo),float(b.hi))
    if not world.step_art(weights,targets):return false
    var state:Array=world.state()
    for c in offsets.size():
        for i in n:
            if driven(c,i):
                var r:Array=rows[c][i]
                var s:Array=state[c*n+i]
                track_error=maxf(track_error,Vector2(r[0],r[1]).distance_to(Vector2(s[0],s[1])))
    contacts=world.fighter_contacts() if pair else []
    var impulse:float=0.
    for contact in contacts:impulse+=float(contact[2])
    if impulse>0.:
        contact_impulse+=impulse
        if contact_tick<0:contact_tick=tick
        # Contact-derived policy, not a second injected impulse.
        if release_tick<0 and impulse>=.5:
            if not release():return false
    tick+=1
    return true

func poses()->Array:
    var state:Array=world.state()
    var out:Array=[]
    for c in offsets.size():
        var m=models[c]
        Common.load_state(m,state.slice(c*n,(c+1)*n))
        out.append(m.pose())
    return out

func snapshot()->Dictionary:
    var states:Array=[]
    for p in players:states.append(p.save())
    var projection:Array=[]
    for m in models:
        var values:Array=[m.template.angles.shoulder_turn,m.template.angles.pelvis_turn]
        for id in GIRDLE:values.append(m.bodies[m.ids[id]].offset)
        projection.append(values)
    return {"projection":projection,"world":world.snapshot(),"hash":world.state_hash(),"players":states,"rows":rows.duplicate(true),"tick":tick,"release":release_tick,"attacker_release":attacker_release_tick,"attacker_release_error":attacker_release_error,"contact":contact_tick,"impulse":contact_impulse,"contacts":contacts.duplicate(true),"release_error":release_error,"track_error":track_error}

func restore(s:Dictionary)->bool:
    if not world.restore(s.world):return false
    for c in players.size():players[c].restore(s.players[c])
    rows=s.rows.duplicate(true)
    for c in models.size():
        var m=models[c]
        var values:Array=s.projection[c]
        m.template.angles.shoulder_turn=values[0]
        m.template.angles.pelvis_turn=values[1]
        for i in GIRDLE.size():m.bodies[m.ids[GIRDLE[i]]].offset=values[i+2]
    tick=s.tick
    release_tick=s.release
    attacker_release_tick=s.attacker_release
    attacker_release_error=s.attacker_release_error
    contact_tick=s.contact
    contact_impulse=s.impulse
    contacts=s.contacts.duplicate(true)
    release_error=s.release_error
    track_error=s.track_error
    return world.state_hash()==s.hash
