extends RefCounted
## 15 thumbnails, read left to right, top to bottom. These are authored
## interpretations, not measured motion capture. Y down, X forward,
## Z anatomical depth. Leg goals are relative to hip, fractions of reach.
## t,yaw,clearance,hips lean,chest flex,chest twist,shoulder twist,
## strike goal xyz, other goal xyz, strike shoulder/elbow, other shoulder/elbow.
const ROWS=[
    [0,0,0,0,0,0,0, [.25,.88,0],[-.28,.90,0], -17,-134,-53,-124],
    [4,-20,0,6,-3,-12,-8, [.42,.69,.10],[-.26,.88,0], -8,-76,-52,-105],
    [8,70,0,8,-7,-22,-15, [-.38,.66,.08],[.32,.86,0], -62,-42,18,-100],
    [12,155,0,-8,8,-28,-17, [.45,.20,.12],[-.10,.91,0], -35,-115,-47,-115],
    [16,252,0,-3,4,-16,-10, [.48,.08,.10],[-.15,.93,0], -36,-103,-61,-88],
    [20,323,4.8,10,-5,-7,4, [.33,.24,.08],[-.26,.42,-.06], -58,-100,-18,-78],
    [24,360,0,7,4,10,9, [.04,.86,0],[.43,.28,-.10], -42,-73,-83,-65],
    [29,440,0,9,-8,-20,-12, [-.12,.87,0],[.32,.73,-.06], 36,-24,-80,-47],
    [33,510,0,11,-6,-30,-18, [.20,.67,.08],[-.26,.89,0], 48,-23,-68,-42],
    [38,592,0,-10,8,-32,-20, [.48,.17,.06],[-.08,.91,0], -34,-106,-40,-102],
    [44,720,0,-40,-10,-5,4, [.865,-.48,0],[-.10,.96,0], 16,-20,-77,-105],
    [47,743,0,-36,-12,10,16, [.94,-.25,-.08],[-.08,.95,0], 21,-18,-68,-98],
    [52,737,0,-8,5,9,6, [.47,.16,.09],[-.10,.92,0], -34,-111,-48,-92],
    [56,722,0,3,-1,3,2, [.25,.72,0],[-.15,.92,0], -24,-117,-52,-106],
    [60,720,0,0,0,0,0, [.25,.88,0],[-.28,.90,0], -17,-134,-53,-124]
]
const CurveSource=preload("res://lab/spatial_lab/spatial_roundhouse_007.gd")
const END:int=60
const HIT:int=44
const TAKEOFF:int=17
const LAND:int=24
const TRANSFER:int=33

static func sample(t:float,anime:bool)->Dictionary:
    var a:Array=ROWS[0]
    var b:Array=ROWS[1]
    for i in range(ROWS.size()-1):
        a=ROWS[i];b=ROWS[i+1]
        if t<=float(b[0]):break
    var u:float=smoothstep(float(a[0]),float(b[0]),t)
    var values:Array=[]
    for j in range(1,13):
        if j in [7,8]:
            var av:=Vector3(float(a[j][0]),float(a[j][1]),float(a[j][2]))
            var bv:=Vector3(float(b[j][0]),float(b[j][1]),float(b[j][2]))
            values.append(av.lerp(bv,u))
        else:
            values.append(lerpf(float(a[j]),float(b[j]),u))
    # Yaw separately sampled on a continuous cubic curve (007).
    var yaw_keys:Array=[]
    for row in ROWS:
        var deg:float=float(row[1])
        if anime:
            if int(row[0])==4:deg=-35.
            if int(row[0])==16:deg=229.
            if int(row[0])==38:deg=562.
            if int(row[0])==47:deg=750.
        yaw_keys.append([float(row[0]),deg])
    var yaw:float=CurveSource.curve(yaw_keys,t)
    var strike:Vector3=values[6]
    var other:Vector3=values[7]
    var clearance:float=0.
    if t>=TAKEOFF and t<LAND:
        clearance=maxf(.35,sin(PI*(t-TAKEOFF+1.)/float(LAND-TAKEOFF+1))* (6.0 if anime else 4.8))
    return {"yaw":yaw,"clearance":clearance,"lean":float(values[2])*(1.15 if anime else 1.),"chest":values[3],"twist":float(values[4])*(1.2 if anime else 1.),"shoulder_twist":values[5],"strike":strike,"other":other,"arms":[values[8],values[9],values[10],values[11]]}
