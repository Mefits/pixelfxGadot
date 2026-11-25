extends RefCounted
## Same geometry and order as Astra's ink_actor.gd.
const EDGE=Color("#172137")
const FAR=Color("#46577b")
const COAT=Color("#5595aa")
const LIGHT=Color("#b4dfd5")
const RED=Color("#e46555")
static func shade(part:String,col:Color,mode:int,active:String)->Color:
    if mode==0:return col
    if part==active:return Color.RED
    if part=="face":return Color.GREEN
    return Color.BLUE
static func segment(c:CanvasItem,a:Vector2,b:Vector2,w:float,v:float,col:Color)->void:
    var n:=(b-a).normalized().orthogonal()
    if n.length_squared()<.1:return
    c.draw_colored_polygon(PackedVector2Array([a+n*w,b+n*v,b-n*v,a-n*w]),col)
    c.draw_circle(a,w,col)
    c.draw_circle(b,v,col)
static func limb(c:CanvasItem,q:Dictionary,side:String,arm:bool,mode:int,active:String)->void:
    var base:String=("shoulder_" if arm else "thigh_")+side
    var mid:String=("elbow_" if arm else "knee_")+side
    var tip:String=("hand_" if arm else "foot_")+side
    var near_side:=side=="near"
    var upper:=shade("other",COAT if near_side else FAR,mode,active)
    segment(c,q[base],q[mid],3.5 if arm else 4.2,2.4 if arm else 3,upper)
    var col:=shade(tip,(LIGHT if near_side else Color("#859ab1")) if arm else Color("#52627a"),mode,active)
    segment(c,q[mid],q[tip],2.5 if arm else 3.0,1.6,col)
    if arm:c.draw_circle(q[tip],2.8,shade(tip,RED if near_side else Color("#ce8070"),mode,active))
    else:segment(c,q[tip]+Vector2(-1,-1.3),q[tip]+Vector2(3.8,-1.1),1.8,1.1,shade(tip,EDGE,mode,active))
static func actor(c:CanvasItem,q:Dictionary,mode:int,active:String)->void:
    for arm in [false,true]:limb(c,q,"far",arm,mode,active)
    limb(c,q,"near",false,mode,active)
    var h:Vector2=q.hips
    var s:Vector2=q.chest
    var axis:Vector2=(s-h).normalized()
    var n:=axis.orthogonal()
    var vertices:=PackedVector2Array([s+5*n,s-4*n,h-4*n-axis*3,h+6*n-axis*2])
    c.draw_colored_polygon(vertices,shade("coat",COAT,mode,active))
    segment(c,h+3*n,h-4*n,1.25,1,shade("coat",RED,mode,active))
    if mode==0:c.draw_line(s+2*n,h-n,LIGHT,1.3)
    var face:Vector2=q.head
    var skin:=shade("face",Color("#f3c6a0"),mode,active)
    c.draw_colored_polygon(PackedVector2Array([face+Vector2(-4,-4),face+Vector2(3,-4),face+Vector2(5,.2),face+Vector2(2,4),face+Vector2(-3,3)]),skin)
    c.draw_colored_polygon(PackedVector2Array([face+Vector2(-6,-5),face+Vector2(-1,-4),face+Vector2(-1,-7),face+Vector2(5,-4),face+Vector2(4,-1),face+Vector2(-3,0),face+Vector2(-4,3)]),shade("hair",EDGE,mode,active))
    if mode==0:c.draw_line(face+Vector2(1,-.5),face+Vector2(4,-1),EDGE,.8)
    limb(c,q,"near",true,mode,active)
