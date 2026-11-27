extends RefCounted
## Compile immutable editor-facing clip slices before starting a match.
const Grid=preload("precision.gd")
const Clips=preload("res://addons/creature/clips.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
static func compile(clip:Dictionary,first:int,last:int,channels:Array,hz:int,rig=null,release:Dictionary={})->Dictionary:
    var frames:Array=[]
    var roots:Array=[]
    var markers:Dictionary={}
    var feet:Array=[]
    var scale:int=hz/60
    for i in range((last-first)*scale+1):
        var pose:=Clips.sample(clip,(first*scale+i)/float(hz),false)
        var angles:Dictionary={}
        for channel in channels:angles[channel]=Grid.scalar(pose.angles.get(channel,0.))
        frames.append(angles)
        roots.append([Grid.scalar(pose.root[0]),Grid.scalar(pose.root[1])] if clip.get("authored_root",false) else [0.,0.])
        var overrides:Dictionary={}
        if not release.is_empty():
            rig.evaluate(pose)
            var frame:=first+float(i)/scale
            for side in release:
                # Four authored source-frame knots: release, full authority,
                # start of landing, restored gait authority.
                var knots:Array=release[side]
                var w:=smoothstep(knots[0],knots[1],frame)*(1.-smoothstep(knots[2],knots[3],frame))
                if w>0.:
                    overrides[side]=[Grid.scalar(w),Grid.point(rig.point("foot_"+side)+IK.toe_vector(pose,side)),Grid.scalar(pose.angles["foot_pitch_"+side])]
        feet.append(overrides)
    for marker in clip.events:
        var local:=roundi(marker.t*hz)-first*scale
        if local>=0 and local<frames.size():
            if not markers.has(local):markers[local]=[]
            markers[local].append(marker.duplicate(true))
    return {"frames":frames,"roots":roots,"markers":markers,"feet":feet,"loop":bool(clip.get("loop",false))}
