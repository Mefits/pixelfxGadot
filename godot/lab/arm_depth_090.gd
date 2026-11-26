extends RefCounted
## Visual-only separation along the existing shared Z buffer. Do not
## move gameplay joints, flatten depth order, or change accepted 069 body.
static func apply(parts:Array,w:float)->void:
    var wrist:float=.8+2.4*4.*w*(1.-w)
    var elbow:float=.8*wrist
    for k in 2:
        var sign_z:float=-1. if k==0 else 1.
        var upper:Dictionary=parts[3+6*k]
        var lower:Dictionary=parts[4+6*k]
        var hand:Dictionary=parts[14+2*k]
        # Shoulder end stays at its original XYZ. Joined elbow and wrist
        # endpoints get the same offsets on adjacent lofts.
        upper.b[2]+=sign_z*elbow
        lower.a[2]+=sign_z*elbow
        lower.b[2]+=sign_z*wrist
        hand.a[2]+=sign_z*wrist
        hand.b[2]+=sign_z*wrist
