extends RefCounted
## Compile immutable editor-facing clip slices before starting a match.
const Grid=preload("precision.gd")
const Clips=preload("res://addons/creature/clips.gd")
static func compile(clip:Dictionary,first:int,last:int,channels:Array,hz:int)->Dictionary:
    var frames:Array=[]
    var markers:Dictionary={}
    var scale:int=hz/60
    for i in range((last-first)*scale+1):
        var pose:=Clips.sample(clip,(first*scale+i)/float(hz),false)
        var angles:Dictionary={}
        for channel in channels:angles[channel]=Grid.scalar(pose.angles.get(channel,0.))
        frames.append(angles)
    for marker in clip.events:
        var local:=roundi(marker.t*hz)-first*scale
        if local>=0 and local<frames.size():
            if not markers.has(local):markers[local]=[]
            markers[local].append(marker.duplicate(true))
    return {"frames":frames,"markers":markers}
