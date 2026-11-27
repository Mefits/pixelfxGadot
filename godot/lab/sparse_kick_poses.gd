extends RefCounted
## v17: three artistic targets, authored for the near striking leg.
## The receiver mirrors girdle projection for the far leg. Ankle targets
## are relative to the striking hip and actual leg reach; Y points down.
const KEYS=[
    {"tick":9,"ankle":Vector2(.27,.26),"pitch":-15.,"lean":-6.,"chest":8.,"head":2.,"pelvis_turn":68.,"shoulder_turn":22.,"strike_shoulder":-34.,"strike_elbow":-112.,"support_shoulder":-61.,"support_elbow":-82.,"support_hip_x":-.035,"support_length":.94,"support_pitch":0.},
    {"tick":12,"ankle":Vector2(.999,.012),"pitch":-105.,"lean":-19.,"chest":-5.,"head":16.,"pelvis_turn":5.,"shoulder_turn":68.,"strike_shoulder":9.,"strike_elbow":-102.,"support_shoulder":-46.,"support_elbow":-118.,"support_hip_x":.34,"support_length":.995,"support_pitch":14.},
    {"tick":22,"ankle":Vector2(.25,.29),"pitch":-12.,"lean":-10.,"chest":5.,"head":5.,"pelvis_turn":58.,"shoulder_turn":30.,"strike_shoulder":-27.,"strike_elbow":-110.,"support_shoulder":-60.,"support_elbow":-86.,"support_hip_x":.045,"support_length":.96,"support_pitch":2.}
]
# Drive the girdles and support first; the distal segment accelerates late.
# Do not apply the entry's smoothstep to the strike itself.
const DRIVE_CHANNELS=["pelvis_turn","shoulder_turn","support_hip_x","support_length","support_pitch","lean","chest","head"]

static func sample(tick:float,acceleration:float=1.)->Dictionary:
    if tick<=int(KEYS[0].tick):return KEYS[0].duplicate(true)
    for i in range(1,KEYS.size()):
        var a:Dictionary=KEYS[i-1]
        var b:Dictionary=KEYS[i]
        if tick<=int(b.tick):
            var t:float=clampf(float(tick-int(a.tick))/float(int(b.tick)-int(a.tick)),0.,1.)
            # 3-tick accelerating extension, then a short follow-through
            # at near-full reach before the return accelerates.
            var limb:float=pow(t,1.+.65*acceleration) if i==1 else smoothstep(0.,1.,t*t)
            var drive:float=smoothstep(0.,1.,minf(1.,t*1.35)) if i==1 else smoothstep(0.,1.,t*t)
            var result:Dictionary={"tick":tick,"ankle":Vector2(a.ankle).lerp(Vector2(b.ankle),limb)}
            for id in a:
                if id not in ["tick","ankle"]:result[id]=lerpf(float(a[id]),float(b[id]),drive if id in DRIVE_CHANNELS or id=="pitch" else limb)
            return result
    return KEYS[-1].duplicate(true)
