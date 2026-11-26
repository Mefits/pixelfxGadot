extends RefCounted
# 071 first clothed youth prototype. Separate material-bearing Loft shells,
# straight hems, explicit hair silhouettes. No image scaling or sprite assets.
const Youth=preload("res://lab/body_dimensions_070.gd")
const Base=preload("res://lab/body_skin_054.gd")
var source=Youth.new(1)
var variant:int
const PALETTE=[
    [0xfff2c9ae,0xffdba58d,0xffb77d70,0xff865865],
    [0xff52749f,0xff34547e,0xff233c61,0xff17283e],
    [0xfff0efeb,0xffd4d9dc,0xffa7b2be,0xff788695],
    [0xff424c65,0xff30394f,0xff20283b,0xff151d2d],
    [0xff9aa7b8,0xff76889f,0xff536780,0xff35455e],
    [0xffdbe5ea,0xffb6c5cf,0xff889aa9,0xff586b7a],
    [0xff34303c,0xff292532,0xff211f2a,0xff171722],
    [0xff536d91,0xff365273,0xff273e5b,0xff1a2c45],
    [0xfff1e4d7,0xffdccbc2,0xffbda59d,0xff947b7d]
]
func _init(i:int=0):
    variant=i
static func make_rig(_i:int=0):
    return Youth.make_rig(1)

func row_at(rows:Array,t:float)->Array:
    if t<=float(rows[0][0]):
        var row:Array=rows[0].duplicate()
        row[0]=t
        return row
    for i in range(1,rows.size()):
        if t<=float(rows[i][0]):
            var a:Array=rows[i-1]
            var b:Array=rows[i]
            var f:float=(t-float(a[0]))/(float(b[0])-float(a[0]))
            return [t,lerpf(a[1],b[1],f),lerpf(a[2],b[2],f),lerpf(a[3],b[3],f),lerpf(a[4],b[4],f)]
    var end:Array=rows[-1].duplicate()
    end[0]=t
    return end

func shell(parts:Array,idx:int,lo:float,hi:float,material:int,pad:float,straight:float=0.,hem:float=0.)->void:
    var p:Dictionary=parts[idx].duplicate(true)
    var src:Array=p.sections
    var rows:Array=[row_at(src,lo)]
    for v in src:
        if float(v[0])>lo and float(v[0])<hi:rows.append(v.duplicate())
    rows.append(row_at(src,hi))
    # Straightening is bounded below by the body envelope, preventing
    # deliberate inward clipping. Axial trim is a straight flat hem.
    var maxw:float=0.
    var maxd:float=0.
    for row in rows:
        maxw=maxf(maxw,maxf(row[1],row[2]))
        maxd=maxf(maxd,row[3])
    for row in rows:
        var t:float=row[0]
        var f:float=(t-lo)/(hi-lo)
        var extra:float=pad+hem*smoothstep(.65,1.,f)
        row[1]=lerpf(row[1],maxw,straight)+extra
        row[2]=lerpf(row[2],maxw,straight)+extra
        row[3]=lerpf(row[3],maxd,straight*.65)+extra
    p.sections=rows
    p.part_id=parts.size()+1
    p.material_id=material
    parts.append(p)

func ell(parts:Array,center:Vector2,z:float,r:Array,rot:float,mat:int)->void:
    Base.ell(parts,center,z,r,rot)
    parts[-1].material_id=mat

func strand(parts:Array,a:Vector2,b:Vector2,z:float,width:float,depth:float,mat:int)->void:
    parts.append({"type":"loft","a":Base.xyz(a,z),"b":Base.xyz(b,z-.12),
        "sections":[[-.10,width*.62,width*.62,depth*.75,0],[.18,width,width,depth,0],
            [.57,width*.60,width*.58,depth*.70,0],[1.,.07,.07,.12,0]],
        "profile":2.2,"part_id":parts.size()+1,"material_id":mat})

func make(q:Dictionary,angles:Dictionary,head_rotation:float)->Array:
    var parts:Array=source.make(q,angles,head_rotation)
    var pad:float=[.24,.38,.52][variant]
    var straight:float=[.08,.35,.58][variant]
    # Shorts seat and two legs overlap around the same deformed pelvis;
    # no balloon-shaped separate primitive. Shirt rests over the waistband.
    shell(parts,0,float(parts[0].sections[0][0]),.25,2,pad,.10)
    for k in 2:
        var j:int=2+6*k
        shell(parts,j+3,float(parts[j+3].sections[0][0]),float(parts[j+3].sections[-1][0]),2,pad,.12)
        shell(parts,j+4,float(parts[j+4].sections[0][0]),.77,2,pad,straight,.12)
    shell(parts,0,.12,float(parts[0].sections[-1][0]),1,pad+.12,straight*.72)
    for k in 2:
        var j:int=2+6*k
        shell(parts,j,float(parts[j].sections[0][0]),float(parts[j].sections[-1][0]),1,pad,.10)
        shell(parts,j+1,float(parts[j+1].sections[0][0]),.59,1,pad,straight,.08)
        # Ankle guards are separate from open-toe sandal straps and sole.
        shell(parts,j+5,.78,float(parts[j+5].sections[-1][0]),4,.10,.12)
        var fi:int=15+2*k
        var shoe:Dictionary=parts[fi]
        # Thin dark sole follows the exact foot axis; leave skin on top/toe.
        var sole:Dictionary=shoe.duplicate(true)
        var a:=Vector2(shoe.a[0],shoe.a[1])
        var b:=Vector2(shoe.b[0],shoe.b[1])
        var u:Vector2=(b-a).normalized()
        var down:=Vector2(-u.y,u.x)
        for key in ["a","b"]:
            sole[key][0]+=.52*down.x
            sole[key][1]+=.52*down.y
        var sr:Array=[]
        for v in shoe.sections:
            sr.append([v[0],.22,.22,float(v[3])+.10,v[4]])
        sole.sections=sr
        sole.material_id=7
        sole.part_id=parts.size()+1
        parts.append(sole)
        shell(parts,fi,.22,.49,7,.16,.04)
    # Standing collar is a separate short shell around the lower neck.
    shell(parts,1,-.08,.47,1,pad+.18,.62)
    # Head-local details follow its rotation; face is a simple three-quarter
    # proxy, not a 3D face turn solver. All details share native depth.
    var hd:Dictionary=parts[18]
    var c:=Vector2(hd.center[0],hd.center[1])
    var r:float=head_rotation
    ell(parts,c+Vector2(-.18,-1.85).rotated(r),-.30,[3.72,3.03,3.18],r,3)
    # Rear locks, then fringe. Tapered asymmetric spikes, not circular hair.
    for v in [[Vector2(-2.5,-2.7),Vector2(-5.0,-4.0),1.18],
        [Vector2(-2.75,-1.8),Vector2(-5.2,-1.4),1.05],
        [Vector2(-2.70,-.9),Vector2(-4.65,1.1),.92],
        [Vector2(-1.6,-3.2),Vector2(-2.9,-5.45),1.15],
        [Vector2(.2,-3.4),Vector2(.0,-5.35),1.0]]:
        strand(parts,c+v[0].rotated(r),c+v[1].rotated(r),-.50,v[2],1.18,3)
    # Headband across upper forehead, metal plate in front.
    ell(parts,c+Vector2(.18,-1.63).rotated(r),2.42,[3.28,.58,.64],r,7)
    ell(parts,c+Vector2(.65,-1.63).rotated(r),3.03,[1.38,.46,.24],r,5)
    for v in [[Vector2(-1.7,-3.1),Vector2(-2.85,.72),.90],
        [Vector2(.15,-3.25),Vector2(-.75,-.48),1.05],
        [Vector2(1.85,-2.8),Vector2(2.68,.48),.94]]:
        strand(parts,c+v[0].rotated(r),c+v[1].rotated(r),2.68,v[2],.82,3)
    # Compact eye/brow marks; small enough to read as pixel art.
    ell(parts,c+Vector2(.95,.32).rotated(r),3.23,[.62,.19,.13],r-.10,6)
    ell(parts,c+Vector2(2.36,.24).rotated(r),2.67,[.31,.16,.12],r-.12,6)
    ell(parts,c+Vector2(1.42,1.80).rotated(r),2.89,[.43,.10,.10],r,6)
    return parts
