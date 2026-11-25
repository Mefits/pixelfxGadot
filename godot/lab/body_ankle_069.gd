extends RefCounted
# 069: distal shin / ankle / proximal foot only. No change to FK or pitch.
const Previous=preload("res://lab/body_anatomy_068.gd")
var source=Previous.new(2)
var variant:int
func _init(i:int=0):
    variant=i

static func make_rig():
    return Previous.make_rig()

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var p:Array=source.make(q,angles,head_rotation)
    if variant==0:return p
    for k in 2:
        var side:String=["far","near"][k]
        var sh:Dictionary=p[7+6*k]
        var f:Dictionary=p[15+2*k]
        var ankle:Vector2=q["foot_"+side]
        var towards_knee:Vector2=(Vector2(q["knee_"+side])-ankle).normalized()
        var fa:=Vector2(f.a[0],f.a[1])
        var fb:=Vector2(f.b[0],f.b[1])
        var fw:Vector2=(fb-fa).normalized()
        var down:=Vector2(-fw.y,fw.x)
        # The old shin extends 7% beyond the ankle with a full-width flat
        # cap. End it inside the ankle rather than through the plantar sole.
        # Preserve all calf rows at or below .75 axial fraction.
        var sr:Array=[]
        for v in sh.sections:
            if float(v[0])<=.75:sr.append(v.duplicate())
        sr.append_array([[.85,1.22,1.28,1.28,0],
            [.93,1.08,1.12,1.13,0],[.985,.86,.91,.94,0],
            [1.012,.40,.42,.50,0]])
        if variant==2:
            # Oblique ankle: recede the distal cap when the tibia lies
            # along the foot or folds towards the plantar side. No joint move.
            var awkward:float=1.-clampf(-towards_knee.dot(down),0.,1.)
            sr[-2][0]-=.025*awkward
            sr[-1][0]-=.035*awkward
        sh.sections=sr
        # Upper half alone changes; keep the original distal foot and
        # plantar half-widths. Depth builds an actual malleolar volume
        # over the buried shin tip instead of a thin foot stuck beneath it.
        var rows:Array=[]
        var lean:float=clampf(towards_knee.dot(fw),-1.,1.)
        for v in f.sections:
            var row:Array=v.duplicate()
            var t:float=row[0]
            if t>=.72:
                rows.append(row)
                continue
            var w:float=smoothstep(0.,.16,t)*(1.-smoothstep(.42,.72,t))
            if variant==1:
                row[1]+=.34*w
                row[3]+=.16*w
            else:
                # Follow the proximal shin gently, not the toe. Higher
                # heel/instep envelope biased with ankle flexion.
                var mid:float=.31+.12*lean
                var bell:float=maxf(0.,1.-absf(t-mid)/.29)
                row[1]+=.20*w+.56*bell
                row[3]+=.16*w+.30*bell
            rows.append(row)
        f.sections=rows
    return p
