extends RefCounted
# New temporal experiment. Baseline sampler copied from motif_search.gd.
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const VAL=preload("res://addons/creature/sdk_validate.gd")
const INK=preload("res://lab/temporal_rd/ink.gd")
const TIPS=["hand_near","hand_far","foot_near","foot_far"]
const CHAINS={"hand_near":["shoulder_near","elbow_near"],"hand_far":["shoulder_far","elbow_far"],"foot_near":["thigh_near","knee_near"],"foot_far":["thigh_far","knee_far"]}
const TILE=192
const HEIGHT=224
const ZOOM=2.4
const FLOOR_Y=204.0
const ORIGIN_X=108.0

static func sample(rig,m:Dictionary,t:float,v:Array)->Dictionary:
    var keys:Array=m.keys
    var k:=0
    while k+1<keys.size() and t>=keys[k+1][0]: k+=1
    var a:Array=keys[k]
    var b:Array=keys[mini(k+1,keys.size()-1)]
    var u:=smoothstep(float(a[0]),float(b[0]),t) if a[0]!=b[0] else 0.0
    var w:Array=[0.0,-.75,-1.0,.55,1.0,1.0,.25,0.0]
    var weight:=lerpf(w[k],w[mini(k+1,w.size()-1)],u)
    if weight<0.0:weight*=1.0+float(v[4])*.32
    var hip:float=lerpf(a[3],b[3],u)+v[0]*weight
    var torso:float=lerpf(a[4],b[4],u)+v[1]*weight
    var pose:=CLIPS.pose({"hips":hip,"chest":torso-hip},lerpf(a[1],b[1],u),lerpf(a[2],b[2],u)+22)
    rig.evaluate(pose)
    var wanted:={}
    var targets:={}
    for i in 4:
        var tip:String=TIPS[i]
        var xy:=Vector2(a[5+i][0],a[5+i][1]).lerp(Vector2(b[5+i][0],b[5+i][1]),u)
        if i<2 and tip!=m.tip:
            xy+=Vector2(v[2],v[3])*weight*(1.0 if i==0 else -.65)
        var chain:Array=CHAINS[tip]
        var span:float=rig.joints[rig.ids[chain[1]]].offset.length()+rig.joints[rig.ids[tip]].offset.length()
        var delta:Vector2=(xy-rig.point(chain[0]))/span
        var pole:=float(m.get("near_leg_pole",1.0)) if i==2 else (1.0 if i==0 else -1.0)
        if m.has("poles"):pole=float(m.poles[i])
        targets[tip]=[delta.x,delta.y,pole]
        wanted[tip]=xy
    pose.angles.head=-torso*.45
    rig.evaluate(pose)
    for tip in targets:
        var pair:Array=CHAINS[tip]
        var upper:Dictionary=rig.joints[rig.ids[pair[0]]]
        var first:Vector2=rig.joints[rig.ids[pair[1]]].offset
        var last:Vector2=rig.joints[rig.ids[tip]].offset
        var d:Array=targets[tip]
        var ray:=Vector2(d[0],d[1])
        var la:=first.length()
        var lb:=last.length()
        var reach:=clampf(ray.length()*(la+lb),absf(la-lb)+.0001,la+lb-.0001)
        var along:float=(la*la-lb*lb+reach*reach)/(2.0*reach)
        var axis:=ray.normalized()
        var mid:=axis*along+Vector2(-axis.y,axis.x)*sqrt(maxf(0,la*la-along*along))*float(d[2])
        var proximal:=mid.angle()-first.angle()
        var distal:=(axis*reach-mid).angle()-last.angle()
        pose.angles[pair[0]]=rad_to_deg(wrapf(proximal-float(rig.rotations[upper.parent]),-PI,PI))
        pose.angles[pair[1]]=rad_to_deg(wrapf(distal-proximal,-PI,PI))
    rig.evaluate(pose)
    var points:={}
    for id in rig.points:
        var p:Vector2=rig.point(id)
        points[id]=[p.x,p.y]
    var plant:=0.0
    for tip in ["foot_near","foot_far"]:
        if absf(wanted[tip].y)<.01:plant=maxf(plant,rig.point(tip).distance_to(wanted[tip]))
    return {"pose":pose,"points":points,"plant":plant,"anchor":rig.point(m.tip).distance_to(wanted[m.tip])}
