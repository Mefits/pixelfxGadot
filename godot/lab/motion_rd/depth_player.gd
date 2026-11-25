extends Node2D
## Load once, then set time by the shared gameplay clock. The sidecar is visual only.
const SKIN = preload("res://lab/motion_rd/depth_skin.gd")
var frames: Array = []
var rate: float = 120.0
var current: int = 0

func set_clip(data: Dictionary) -> bool:
    if data.get("format") != "lab.joints3.v1" or not data.get("frames") is Array or data.frames.is_empty():
        return false
    if not data.get("hz") is float and not data.get("hz") is int:
        return false
    if float(data.hz) <= 0 or not is_finite(float(data.hz)):
        return false
    var decoded: Array = []
    for src in data.frames:
        var joints := {}
        for id in ["hips","chest","head","shoulder_far","elbow_far","hand_far","thigh_far","knee_far","foot_far",
                   "shoulder_near","elbow_near","hand_near","thigh_near","knee_near","foot_near"]:
            if not src is Dictionary or not src.get(id) is Array or src[id].size() != 3:
                return false
            for value in src[id]:
                if not (value is float or value is int) or not is_finite(float(value)):
                    return false
            var v := Vector3(src[id][0],src[id][1],src[id][2])
            if v.z >= SKIN.FOCAL-1.0:
                return false
            joints[id] = v
        decoded.append(joints)
    frames = decoded
    rate = float(data.hz)
    seek(0)
    return true

func seek(seconds: float) -> void:
    if not frames.is_empty():
        current = clampi(floori(seconds*rate+0.00001),0,frames.size()-1)
        queue_redraw()

func _draw() -> void:
    if not frames.is_empty():
        SKIN.draw(self,frames[current])
