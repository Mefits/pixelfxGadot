extends RefCounted
## Three authored poses, reference #4 / #6 / #8. Near striking role.
## Polar ankle goals in the projected side plane: radius / actual leg reach,
## angle from forward (+X), with positive Y down. Rotation is projected,
## not a physical 3D spin. Other channels retain the v17a receiver contract.
const KEYS=[
    {"tick":10,"radius":.38,"angle":43.,"pitch":-32.,"lean":-10.,"chest":15.,"head":-3.,"pelvis_turn":79.,"shoulder_turn":13.,"strike_shoulder":-15.,"strike_elbow":-97.,"support_shoulder":-84.,"support_elbow":-43.,"support_hip_x":-.06,"support_length":.95,"support_pitch":0.},
    {"tick":13,"radius":.999,"angle":-27.,"pitch":-24.,"lean":-31.,"chest":-18.,"head":29.,"pelvis_turn":9.,"shoulder_turn":72.,"strike_shoulder":17.,"strike_elbow":-105.,"support_shoulder":-87.,"support_elbow":-37.,"support_hip_x":.36,"support_length":.995,"support_pitch":12.},
    {"tick":26,"radius":.34,"angle":78.,"pitch":-9.,"lean":-22.,"chest":-9.,"head":19.,"pelvis_turn":2.,"shoulder_turn":87.,"strike_shoulder":-25.,"strike_elbow":-101.,"support_shoulder":-81.,"support_elbow":-23.,"support_hip_x":.06,"support_length":.96,"support_pitch":3.}
]
const DRIVE_CHANNELS=["pelvis_turn","shoulder_turn","support_hip_x","support_length","support_pitch","lean","chest","head","pitch"]

static func sample(tick:float,acceleration:float=1.)->Dictionary:
    var a:Dictionary=KEYS[0]
    var b:Dictionary=KEYS[1]
    var limb:float=0.
    var drive:float=0.
    var radius:float=float(a.radius)
    var angle:float=float(a.angle)
    if tick>10 and tick<=13:
        var t:float=clampf(float(tick-10)/3.,0.,1.)
        limb=pow(t,1.+.65*acceleration)
        drive=smoothstep(0.,1.,minf(1.,t*1.35))
        radius=lerpf(float(a.radius),float(b.radius),limb)
        # Lift/sweep the thigh before the distal segment reaches full length.
        angle=lerpf(float(a.angle),float(b.angle),smoothstep(0.,1.,t))
    elif tick>13:
        a=KEYS[1]
        b=KEYS[2]
        var t:float=clampf(float(tick-13)/13.,0.,1.)
        limb=smoothstep(0.,1.,t)
        drive=smoothstep(0.,1.,t)
        # Follow through for five ticks on a rising arc, then fold the leg
        # before lowering it. Derived arc, not an extra authored pose.
        if tick<=18:
            var arc:float=smoothstep(0.,1.,float(tick-13)/5.)
            radius=lerpf(float(a.radius),.91,arc)
            angle=lerpf(float(a.angle),-42.,arc)
        else:
            var fold:float=clampf(float(tick-18)/8.,0.,1.)
            radius=lerpf(.91,float(b.radius),smoothstep(0.,1.,minf(1.,fold*1.35)))
            angle=lerpf(-42.,float(b.angle),smoothstep(0.,1.,fold*fold))
    var result:Dictionary={"tick":tick,"ankle":Vector2.RIGHT.rotated(deg_to_rad(angle))*radius}
    for id in a:
        if id not in ["tick","radius","angle"]:
            result[id]=lerpf(float(a[id]),float(b[id]),drive if id in DRIVE_CHANNELS else limb)
    return result
