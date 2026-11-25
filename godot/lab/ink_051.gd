extends RefCounted
## Lab 0.51a: visual envelope only. No joint/pose mutations.
const EDGE=Color("#172137")
const FAR=Color("#46577b")
const COAT=Color("#5595aa")
const LIGHT=Color("#b4dfd5")
const RED=Color("#e46555")
const PANTS=Color("#62758b")
static func poly(c:CanvasItem,p:Array,col:Color)->void:
    c.draw_colored_polygon(PackedVector2Array(p),col)

static func joined(c:CanvasItem,a:Vector2,b:Vector2,d:Vector2,w0:float,w1:float,w2:float,upper:Color,lower:Color)->void:
    var u:Vector2=(b-a).normalized()
    var v:Vector2=(d-b).normalized()
    if u.length_squared()<.001 or v.length_squared()<.001:return
    var n0:=u.orthogonal()
    var n1:=v.orthogonal()
    # Shared beveled seam; no discs at the attachment or elbow/knee.
    var bis:Vector2=(n0+n1).normalized()
    if bis.length_squared()<.01:bis=n0
    var m:Vector2=bis*minf(w1/maxf(.65,absf(bis.dot(n0))),w1*1.23)
    poly(c,[a+n0*w0,b+m,b-m,a-n0*w0],upper)
    poly(c,[b+m,d+n1*w2,d-n1*w2,b-m],lower)

static func limb(c:CanvasItem,q:Dictionary,side:String,arm:bool,fit:bool)->void:
    var base:String=("shoulder_" if arm else "thigh_")+side
    var mid:String=("elbow_" if arm else "knee_")+side
    var tip:String=("hand_" if arm else "foot_")+side
    var near_side:bool=side=="near"
    var a:Vector2=q[base]
    var b:Vector2=q[mid]
    var d:Vector2=q[tip]
    var center:Vector2=q.chest if arm else q.hips
    # Fitted garment roots extend under the torso rather than creating a cap
    # centered outside it. This is ink, not a shifted skeleton.
    if fit:a=a.lerp(center,.38 if arm else .32)
    var upper:Color=(COAT if near_side else FAR) if arm else (PANTS if near_side else FAR)
    var lower:Color=(LIGHT if near_side else Color("#a4b8c9")) if arm else Color("#52627a")
    var root_width:float=(2.4 if arm else 3.15) if fit else (2.7 if arm else 3.7)
    var mid_width:float=(1.65 if arm else 2.1) if fit else (2.1 if arm else 2.6)
    joined(c,a,b,d,root_width,mid_width,1.4 if fit else (1.4 if arm else 2.6),upper,lower)
    if arm:
        var axis:Vector2=(d-b).normalized()
        var n:=axis.orthogonal()
        var glove:Color=RED if near_side else Color("#ce8070")
        poly(c,[d-axis*2.0+n*1.45,d+axis*1.7+n*1.85,d+axis*2.3,d+axis*1.7-n*1.85,d-axis*2.0-n*1.45],glove)
    else:
        # Preserve original foot outline and horizontal tip for this experiment.
        poly(c,[d+Vector2(-2,-2.7),d+Vector2(1,-2.7),d+Vector2(2,-1.1),d+Vector2(4,-.9),d+Vector2(4,0),d+Vector2(-2,0)],EDGE)

static func actor(c:CanvasItem,q:Dictionary,fit:bool)->void:
    limb(c,q,"far",false,fit)
    limb(c,q,"far",true,fit)
    limb(c,q,"near",false,fit)
    var h:Vector2=q.hips
    var s:Vector2=q.chest
    var axis:Vector2=(s-h).normalized()
    var n:=axis.orthogonal()
    var face:Vector2=Vector2(q.head)-axis*2.6
    var skin:=Color("#f3c6a0")
    poly(c,[s+axis*1.1+n*2.25,face-axis*2.1+n*2.1,face-axis*2.1-n*2.1,s+axis*1.1-n*2.25],skin)
    if fit:
        # One trouser yoke covers both moving hip attachments. No thigh caps.
        var hf:Vector2=q.thigh_far
        var hn:Vector2=q.thigh_near
        var left:Vector2=hf if hf.dot(n)<hn.dot(n) else hn
        var right:Vector2=hn if hf.dot(n)<hn.dot(n) else hf
        poly(c,[h+axis*2.2-n*3.7,h+axis*2.2+n*3.7,right+n*1.9-axis*2.0,h-axis*4.0,left-n*1.9-axis*2.0],PANTS)
    # Torso shoulder line is a single tapered shape, not a chain of circles.
    var sw:float=4.9 if fit else 5.2
    var waist:float=3.1 if fit else 3.8
    poly(c,[s+axis*.7+n*sw,s+axis*.7-n*sw,s-axis*5.7-n*3.5,h-axis*1.1-n*waist,h-axis*1.1+n*waist,s-axis*5.7+n*3.5],COAT)
    poly(c,[h+axis*.25-n*waist,h+axis*.25+n*waist,h-axis*1.45+n*waist,h-axis*1.45-n*waist],RED)
    c.draw_line(s+n*1.8,h+axis*.8-n*.6,LIGHT,1.05 if fit else 1.3)
    poly(c,[face+Vector2(-4,-4),face+Vector2(3,-4),face+Vector2(5,.2),face+Vector2(2,4),face+Vector2(-3,3)],skin)
    poly(c,[face+Vector2(-6,-5),face+Vector2(-1,-4),face+Vector2(-1,-7),face+Vector2(5,-4),face+Vector2(4,-1),face+Vector2(-3,0),face+Vector2(-4,3)],EDGE)
    c.draw_line(face+Vector2(1,-.5),face+Vector2(4,-1),EDGE,.8)
    limb(c,q,"near",true,fit)
